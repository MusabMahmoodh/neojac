---
description: neojac launch, an app sent to the hosting platform and looked after there - signing in, launching a project's app from its source, the name it is launched as and its address, what is sent and what is not, its secrets, its logs, its domains, and where the session is kept.
keywords: neojac launch, deploy, hosting, hosting platform, launch login, launch deploy, launch secrets, launch logs, launch domains, launch.json
---
# launch

`neojac launch` puts an app a project builds on the hosting platform, and looks after it there. The
platform builds the app from the project's source, runs as many instances of it as its callers
need and none while it has no callers, and keeps what the app keeps (its graph, its accounts, its
files) where every instance reaches it.

```sh
neojac launch login                          # sign in, once
neojac launch deploy web                     # launch the project's app `web`
neojac launch secrets set ANTHROPIC_API_KEY  # a variable of its environment
neojac launch logs                           # what its instances said last
neojac launch domains add shop.example       # another name it answers at
neojac launch delete                         # take the app away, with what it keeps
```

## Signing in

`neojac launch login` signs in to the platform, which is at `https://launch.neojac.dev`; an address
given after it names another platform. Signing in is done in a browser, at a page of the platform:

```text
To sign in to https://launch.neojac.dev, open

    https://launch.neojac.dev/__jac/auth/device?code=WRQB-NRZQ

sign in there, and check that the page shows the code WRQB-NRZQ
```

Open the link on this machine or on any other. The page asks for a username and a password, or makes
an account (`Create account`), shows the code, and asks whether the program is yours: `Sign it in`.
`login` waits for that, ten minutes at most, and nothing typed at the page comes to this machine but
the session. The session is kept for the commands that follow, on this machine and for this user:

| System | The session's file |
|---|---|
| Linux | `$XDG_CONFIG_HOME/neojac/launch.json`, else `~/.config/neojac/launch.json` |
| macOS | `~/Library/Application Support/neojac/launch.json` |
| Windows | `%APPDATA%\neojac\launch.json` |

`NEOJAC_CONFIG_DIR` names another directory for it ([Environment](../reference/environment.md)).
The file holds the address, the account's name and the session's token, and only its owner can
read it. Every other command of `launch` says `you are not signed in` until there is one.

## Launching an app

`neojac launch deploy <app>`, run in a project, launches the app of that name, one the project's
`archwire.jac` declares and `neojac build <app>` builds:

- **The project's directory is sent**, packed. The platform builds from source, with its own
  compiler, so that the app is built for the machines it runs on.
- **What a build or an install made is not sent:** `dist/`, `.jac/`, `node_modules/`, `target/`,
  `__pycache__/`, `replaced-by-neojac/`, the packages fetched into `eco/jac/`, `.git/`, and
  symbolic links. The platform installs the project's packages as `jac.toml` and `jac.lock` say,
  as `neojac install --frozen` does: a project that builds from a fresh clone builds there.
- **A package the project uses from outside its directory is refused**, since it is not sent:
  `{ path = "../shared" }` names nothing on the platform. Declare it by a version or by a
  repository ([Packages](packages.md#jac-packages)).
- **What the build says is printed as it says it,** then the app's address once it answers. A
  build that fails ends the command with status 1, and the app that was live stays live.
- **A launch waits its turn for a build.** The platform runs a few builds at once, and one of an
  account's at a time: `deploy` says it waits, and goes on when its build starts. A build has 20
  minutes.
- **A packed project is at most 256 MiB.**

An app is launched under a name, which is the first word of its address. It is the project's name
unless `--as <name>` gives another: lower-case letters, digits and hyphens, at most 40 characters.
A name belongs to the account that first launched under it, and to one app of one project:

```sh
neojac launch deploy web --as shop     # https://shop.<the platform's domain>
neojac launch deploy admin --as shop-admin
```

Launching again under the same name replaces the app with a new build of it. What it kept stays.

### What changes where an app is launched

The app is the same program. What differs is where it keeps things, since an instance of it lasts
only as long as it has callers and there may be several at once:

| What | On one machine | Launched |
|---|---|---|
| The graph ([An app's data](../apps/data.md)) | A file in the app's data directory | A database of the app's own |
| Accounts and sessions ([The server](../apps/server.md)) | A file beside it | The same database |
| Files ([Files](../apps/files.md)) | A directory beside it | Object storage, under the app's own prefix |
| Rate limits | One process's memory | Counted by every instance together |
| Scheduled functions | Run by the one process | Each run once a period, by one instance; an app asleep is woken for them, so one scheduled every few seconds never sleeps (`JAC_TICKS_OFF`, set as a secret, turns them off) |
| Jobs | A copy of the program on the same machine | A copy started for the job, which outlives the instance that asked |

The platform's build binds a plugin of its own for each of these, in place of the standard one
([Plugins](../apps/plugins.md)). A project that binds one of them to a plugin of its own keeps its
choice. The app's data directory still exists, and lasts as long as one instance: nothing an app
means to keep belongs there.

## What an app is held to

An app shares the platform with others, so what one may take is bounded, and what it may reach is
its own:

| | An app has |
|---|---|
| Instances | As many as its callers need, 5 at most unless the platform is told otherwise, and never more than 10 |
| An instance | 1 CPU and 256 MiB of memory, and 1 GiB of disk at most. Its disk lasts as long as the instance |
| Jobs | Each in a copy of the app started for it, with 1 CPU and 256 MiB |
| Its database | 1 GiB, a connection for each of its instances and jobs, and 60 seconds for one statement |
| Its files | 5 GiB |
| What its instances share (limits, schedules, jobs' notes) | 16 MiB |
| Its logs | 7 days, and 64 MiB a day on each machine its instances run on: past that a line says the rest was not kept |
| Its own domains | 5 |
| The network | Requests reach it through the platform's gateway alone, which tells it each caller's address. It reaches the internet and its own database, files and shared state, and no other app |

Where the platform has them, **each instance, each job and each build runs in a virtual machine of
its own**, with a kernel of its own, on machines no part of the platform itself runs on, and has no
connection in or out until the rules above are in force for it. An app's code runs unprivileged
there, and a job it starts runs the app's own image and nothing else.

An account has at most 3 apps, and launches at most 10 times an hour. The numbers here are the
platform's defaults: whoever runs a platform sets each.

**An app over its database or its files is held:** its instances are taken away, its address
answers nothing, and `deploy` and `logs` say why (`'shop' is held: ...`). What it keeps
stays. It is held until its owner deletes it, or whoever runs the platform gives it more; launching
it again once it is under its bound brings it back. An app over what its instances share may read
and delete there, and not write, until it is under.

## Secrets

An app's secrets are variables of its environment that are never written in the project: an API's
key, an OAuth app's secret.

```sh
neojac launch secrets                         # the names that are set
neojac launch secrets set ANTHROPIC_API_KEY   # asked for, and not echoed
neojac launch secrets set MODE=fast           # given on the line
echo -n "$KEY" | neojac launch secrets set ANTHROPIC_API_KEY
neojac launch secrets unset MODE
```

A value is never printed back. An app that is running starts again with a secret that changed. The
variables the platform sets itself (the app's database, its storage) are not the owner's to set.

## Logs

`neojac launch logs` prints the last lines the app's instances and jobs said, 200 unless
`--lines <n>` says how many. Where the platform keeps logs they are kept for 7 days, whether or
not an instance runs now; a platform on one machine has only what running instances said.

## Domains

`neojac launch domains add <domain>` has another name reach the app, once its owner has shown the
domain is theirs:

```text
$ neojac launch domains add shop.example
shop.example is shop's once these records say so, where the domain's DNS is kept:
    _acme-challenge.shop.example  CNAME  k3j9x2m4p7q8r1t5v6w7.challenges.neojac.dev
    shop.example                  CNAME  shop.neojac.app
`neojac launch domains` says how far it has got
```

- **The first record is the proof,** and what the domain's certificate is issued and renewed by: it
  stays for as long as the domain is the app's. The name it points at is the account's own, so no
  one else's record proves a domain for them.
- **The second sends the domain's callers to the app.** It can wait: the certificate is made
  before any caller comes, so a site that is live elsewhere moves without a gap. A domain with no
  name before it (`example.org` itself) can't hold a `CNAME`: where its DNS is kept, use what that
  provider calls `ALIAS`, `ANAME` or CNAME flattening, to the same name.
- **`neojac launch domains` lists each domain and how far it has got:** `proving` (the record is
  not there yet, or does not name the account), `certifying` (the certificate is being issued, a
  minute or two), `live`, or `failed` with why. A domain that is not proven in 7 days is let go.
- **`remove` takes one away,** with its certificate. Both records can then go.

A domain reaches one app, and is mapped to an app that is live. The platform's own names are no
app's to map (`'...' is the platform's`). A platform on one machine maps a domain at once: there is
no one to prove it to.

## Deleting an app

`neojac launch delete` takes the app away for good: its instances, its database with its accounts
and its graph, its files, its logs, its domains, its images and its name, which anyone may then
launch under. It asks for the app's name to be typed; `--yes` says it for a script. The platform
takes it away in the minute that follows: until all it kept is gone, launching under its name is
refused (`'shop' is being deleted`).

```sh
neojac launch delete --as shop
```

## The app a command is about

`deploy` names the app it launches. `secrets`, `logs`, `domains` and `delete` are about the app the project
they are run in is launched as: the project's name, or `--as <name>`, which also lets them be run
from anywhere.

## What goes wrong

| It says | What happened |
|---|---|
| `you are not signed in` | No session is kept here, or the platform no longer takes it: `neojac launch login` |
| `this sign-in was turned away` | Whoever was at the page chose `Turn it away` |
| `not signed in: no one answered at the page in time` | No one said the program was theirs in the ten minutes the platform waits: `neojac launch login` again |
| `<address> could not be reached` | The platform did not answer |
| `the name '...' is taken by another account's app` | Launch under another name, with `--as` |
| `'...' is the project's app '...'` | That name is another app of a project: an app has a name of its own |
| `the package '...' is at ..., outside the project` | A package declared by a path that leaves the project's directory |
| `launch <n> of <name> failed` | Its build failed, or the app did not start: what was printed above says why |
| `you have no app called '...'` | No app of that name is this account's |
| `an account has at most 3 apps` | Delete one to launch another: `neojac launch delete` |
| `an account launches at most 10 times an hour` | It says how long to wait |
| `... launches wait for a build already` | The platform's builds are full: launch again in a while |
| `'...' is held: ...` | The app is over its database or its files ([above](#what-an-app-is-held-to)) |
| `'...' is being deleted` | A deletion that was asked for is under way |
| `'...' is mapped to another app` | A domain reaches one app |
| `an app has at most 5 domains of its own` | Remove one to add another |
