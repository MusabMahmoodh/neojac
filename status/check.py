"""Ask each address the status page reports on, once, and add what came back
to the record in the directory given: `status.json`, which the page reads.

The record holds every check of the last two days, and for each of the last
ninety days how many checks of each address were made and how many it
answered, so that it stays a few hundred kilobytes however long it is kept.
An address answers when it gives the status expected within ten seconds.
"""

import datetime
import json
import os
import sys
import urllib.error
import urllib.request

# What is asked, each named for what people use it for, with the line the page
# says under the name in place of the address asked: the site; the platform's
# own address, which signs people in and takes launches (asked for what
# signing in takes, which the runtime of every app answers); the public page of
# the usage statistics; and one app launched on the platform, which a request
# wakes if it sleeps. That one app stands for the apps: the platform's gateway,
# its certificates and its waking an app are what it shows. No other app is
# asked or named here: how an app does is its owner's to know.
ASKED = [
    {"name": "The site", "at": "neojac.dev", "url": "https://neojac.dev/", "expects": 200},
    {
        "name": "Signing in and launching",
        "at": "launch.neojac.dev",
        "url": "https://launch.neojac.dev/__jac/auth/",
        "expects": 200,
    },
    {
        "name": "Usage statistics",
        "at": "telemetry.neojac.dev",
        "url": "https://telemetry.neojac.dev/totals",
        "expects": 200,
    },
    {
        "name": "Launched apps",
        "at": "one app launched on the platform, jaclang-org.neojac.app, asked in their place",
        "url": "https://jaclang-org.neojac.app/",
        "expects": 200,
    },
]
SECONDS = 10
CHECKS_KEPT_HOURS = 48
DAYS_KEPT = 90


def asked(url, expects):
    """Whether `url` answered with the status expected, and what it did."""
    began = datetime.datetime.now(datetime.timezone.utc)
    try:
        with urllib.request.urlopen(urllib.request.Request(url, method="GET"), timeout=SECONDS) as reply:
            status = reply.status
            said = str(status)
    except urllib.error.HTTPError as e:
        status = e.code
        said = str(status)
    except Exception as e:  # a name that does not resolve, a refused connection, a wait too long
        status = 0
        said = type(e).__name__
    took = (datetime.datetime.now(datetime.timezone.utc) - began).total_seconds()
    return status == expects, said, round(took, 2)


def main(record):
    path = os.path.join(record, "status.json")
    try:
        with open(path) as f:
            kept = json.load(f)
    except (OSError, ValueError):
        kept = {"checks": [], "days": {}}
    now = datetime.datetime.now(datetime.timezone.utc)
    stamp = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    day = now.strftime("%Y-%m-%d")
    for one in ASKED:
        ok, said, took = asked(one["url"], one["expects"])
        kept["checks"].append({"at": stamp, "name": one["name"], "ok": ok, "said": said, "seconds": took})
        of_day = kept["days"].setdefault(day, {}).setdefault(one["name"], {"checks": 0, "answered": 0})
        of_day["checks"] += 1
        of_day["answered"] += 1 if ok else 0
    oldest = (now - datetime.timedelta(hours=CHECKS_KEPT_HOURS)).strftime("%Y-%m-%dT%H:%M:%SZ")
    kept["checks"] = [c for c in kept["checks"] if c["at"] >= oldest]
    first_day = (now - datetime.timedelta(days=DAYS_KEPT)).strftime("%Y-%m-%d")
    # Only what is asked now is kept: a name no longer asked leaves the record.
    names = [one["name"] for one in ASKED]
    kept["checks"] = [c for c in kept["checks"] if c["name"] in names]
    kept["days"] = {
        d: {name: of for name, of in v.items() if name in names}
        for d, v in sorted(kept["days"].items())
        if d >= first_day
    }
    kept["asked"] = [{"name": one["name"], "at": one["at"]} for one in ASKED]
    kept["at"] = stamp
    with open(path + ".new", "w") as f:
        json.dump(kept, f, separators=(",", ":"))
    os.replace(path + ".new", path)


if __name__ == "__main__":
    main(sys.argv[1])
