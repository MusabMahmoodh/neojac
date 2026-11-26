import hmac;
import json;
import os;
import sys;
import from auth.contract { Auth, AuthHost, Rejected, Session, SignIn }
import from mail.contract { MailNotSent }
import from transport.contract { Request, Response, json_fail }

glob _auth: list[dyn Auth] = [];

obj AuthProgram(ProgramHost, AuthHost) {
    def windowed -> bool;

    def consume_limit(scope: str, actor: str, limit: int, seconds: int) -> int;

    def sends_mail -> bool;

    def send_mail(to: str, subject: str, text: str);
}

def:pub open_auth;
def:pub address_checked -> bool;
def:pub auth_caller(headers: dict[str, str]) -> str;
def:pub deployment_signed(r: Request) -> bool;

def asked(a: SignIn) -> dict[str, any];
def signed(s: Session) -> dict[str, any];

glob CAME_BACK: str = """<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Signing in</title>
<body>
<script>
(async () => {
    let kept = {};
    try {
        kept = JSON.parse(sessionStorage.getItem("jac_sign_in") || "{}") || {};
        sessionStorage.removeItem("jac_sign_in");
    } catch (_) {}
    const given = Object.assign({}, Object.fromEntries(new URLSearchParams(location.search)), kept.keeps || {});
    let said = "the app could not be reached";
    try {
        const res = await fetch(location.pathname, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(given) });
        const data = await res.json();
        if (data.ok) {
            if (data.data.token) localStorage.setItem("jac_token", data.data.token);
            if (data.data.name) localStorage.setItem("jac_name", data.data.name);
            else localStorage.removeItem("jac_name");
            // (Back to a path of this origin, and nowhere else.)
            const b = kept.back;
            const back = typeof b === "string" && b[0] === "/" && b[1] !== "/" && b.charCodeAt(1) !== 92 ? b : "/";
            location.replace(back);
            return;
        }
        said = data.detail;
    } catch (_) {}
    const p = document.createElement("p");
    p.textContent = "Signing in did not work: " + said + ". ";
    const home = document.createElement("a");
    home.href = "/";
    home.textContent = "Go back";
    p.appendChild(home);
    document.body.appendChild(p);
})();
</script>
""";

glob DEVICE: str = """<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer">
<title>Sign in a program</title>
<style>
body{margin:0;min-height:100vh;display:grid;place-items:center;font:16px system-ui,sans-serif;background:Canvas;color:CanvasText;color-scheme:light dark}
main{display:grid;gap:.9rem;width:22rem;max-width:calc(100vw - 2rem);padding:1.5rem}
h1{font-size:1.3rem;margin:0}
p{margin:0;line-height:1.45}
label{display:grid;gap:.25rem}
input{font:inherit;padding:.5rem}
input.code{font:600 1.5rem ui-monospace,monospace;letter-spacing:.12em;text-align:center;text-transform:uppercase}
button{font:inherit;padding:.5rem 1rem}
.row{display:flex;flex-wrap:wrap;gap:.5rem;justify-content:flex-end}
.who{display:flex;gap:.5rem;align-items:baseline;justify-content:space-between}
.who button{padding:.15rem .6rem;font-size:.85rem;white-space:nowrap}
.said{color:#b00020;min-height:1.25em}
@media (prefers-color-scheme: dark){.said{color:#ff8a80}}
.said.told{color:inherit}
button.forgot{justify-self:start;padding:0;border:0;background:none;color:LinkText;text-decoration:underline;cursor:pointer}
</style>
<body>
<main></main>
<script>
(() => {
    const main = document.querySelector("main");
    const base = location.pathname.slice(0, location.pathname.lastIndexOf("/device")) + "/";
    const el = (tag, text, cls) => { const e = document.createElement(tag); if (text !== undefined) e.textContent = text; if (cls) e.className = cls; return e; };
    const show = (...parts) => main.replaceChildren(el("h1", "Sign in a program"), ...parts);
    const token = () => { try { return localStorage.getItem("jac_token") || ""; } catch (_) { return ""; } };
    const keep = (session) => {
        if (session.token) localStorage.setItem("jac_token", session.token);
        if (session.name) localStorage.setItem("jac_name", session.name);
        else localStorage.removeItem("jac_name");
    };
    const ask = async (path, body) => {
        const headers = {};
        if (token()) headers.Authorization = "Bearer " + token();
        if (body !== undefined) headers["Content-Type"] = "application/json";
        try {
            const res = await fetch(base + path, { method: body === undefined ? "GET" : "POST", headers, body: body === undefined ? undefined : JSON.stringify(body) });
            const data = await res.json();
            return data && typeof data === "object" ? data : { ok: false, detail: "the app gave no answer" };
        } catch (_) {
            return { ok: false, detail: "the app could not be reached" };
        }
    };
    // To the place a way of signing in is done at: what it asks the page to
    // keep stays in this tab, with this page as where to come back to
    // (CAME_BACK reads both).
    const leave = (url, keeps) => {
        sessionStorage.setItem("jac_sign_in", JSON.stringify({ keeps, back: location.pathname + location.search }));
        location.assign(url);
    };
    // The plugin's form: a field for each it asks for, a button for each way
    // of signing in, and what it refused the last try with.
    const signIn = (asks) => {
        const form = el("form");
        form.style.display = "contents";
        const inputs = {};
        for (const f of asks.fields) {
            const row = el("label", f.label || f.name);
            const input = el("input");
            input.name = f.name;
            input.type = f.secret ? "password" : "text";
            input.autocapitalize = "none";
            row.appendChild(input);
            form.appendChild(row);
            inputs[f.name] = input;
        }
        const said = el("p", "", "said");
        said.setAttribute("role", "alert");
        form.appendChild(said);
        const run = async (action) => {
            if (action.redirect) return leave(action.redirect, action.keeps || {});
            const given = {};
            for (const name of action.needs) if (inputs[name]) given[name] = inputs[name].value;
            const got = await ask(action.name, given);
            if (got.ok) { keep(got.data); begin(); }
            else { said.className = "said"; said.textContent = got.detail; }
        };
        const row = el("div", undefined, "row");
        asks.actions.forEach((action, k) => {
            const b = el("button", action.label || action.name);
            b.type = k === 0 ? "submit" : "button";
            b.onclick = (ev) => { ev.preventDefault(); run(action); };
            row.appendChild(b);
        });
        form.appendChild(row);
        // One who forgot their password is mailed a link that sets another,
        // where the plugin mails such links: to the account the field it
        // names names.
        if (asks.forgot) {
            const forgot = el("button", "Forgot your password?", "forgot");
            forgot.type = "button";
            forgot.onclick = async () => {
                const name = inputs[asks.forgot] ? inputs[asks.forgot].value : "";
                const got = await ask("forgot", { name });
                said.className = got.ok ? "said told" : "said";
                said.textContent = got.ok ? "If an account has that name or address, a link to set a new password was mailed to it." : got.detail;
            };
            form.appendChild(forgot);
        }
        form.onsubmit = (ev) => { ev.preventDefault(); if (asks.actions.length > 0) run(asks.actions[0]); };
        show(el("p", "Sign in to " + location.host + " first. You are then asked whether the program is yours."), form);
        const first = form.querySelector("input");
        if (first) first.focus();
    };
    // The caller is signed in: whether the program showing the code is theirs.
    const decide = (user) => {
        const name = (() => { try { return localStorage.getItem("jac_name") || user; } catch (_) { return user; } })();
        const who = el("div", undefined, "who");
        who.appendChild(el("span", "Signed in to " + location.host + " as " + name));
        const out = el("button", "Sign out");
        out.type = "button";
        out.onclick = async () => { await ask("logout", {}); localStorage.removeItem("jac_token"); localStorage.removeItem("jac_name"); begin(); };
        who.appendChild(out);
        const field = el("label", "The code the program shows");
        const code = el("input", undefined, "code");
        code.value = new URLSearchParams(location.search).get("code") || "";
        code.autocomplete = "off";
        code.spellcheck = false;
        field.appendChild(code);
        const said = el("p", "", "said");
        said.setAttribute("role", "alert");
        const answer = async (allow) => {
            const got = await ask(allow ? "device/allow" : "device/refuse", { code: code.value });
            if (!got.ok) { said.textContent = got.detail; return; }
            show(el("p", allow ? "The program is signed in as " + name + ". You can close this page." : "The program was turned away. You can close this page."));
        };
        const row = el("div", undefined, "row");
        const no = el("button", "Turn it away");
        no.type = "button";
        no.onclick = () => answer(false);
        const yes = el("button", "Sign it in");
        yes.type = "button";
        yes.onclick = () => answer(true);
        row.append(no, yes);
        show(
            who,
            el("p", "A program is waiting to be signed in as you. Sign it in only if you started it yourself, and the code it shows is the one here. If someone sent you this page, turn it away: whoever holds the program would be you."),
            field,
            said,
            row,
        );
    };
    const begin = async () => {
        const me = await ask("me");
        if (me.ok) return decide(me.data.user);
        const got = await ask("");
        if (!got.ok) return show(el("p", "Signing in is not possible now: " + got.detail + "."));
        const asks = got.data;
        if (asks.session) {
            keep(asks.session);
            return decide(asks.session.user);
        }
        if (asks.fields.length === 0 && asks.actions.length === 0) {
            if (asks.redirect) return leave(asks.redirect, {});
            return show(el("p", "This app offers no way of signing in."));
        }
        signIn(asks);
    };
    begin();
})();
</script>
</html>
""";

glob MAILED: str = """<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer">
<title>Your account</title>
<style>
body{margin:0;min-height:100vh;display:grid;place-items:center;font:16px system-ui,sans-serif;background:Canvas;color:CanvasText;color-scheme:light dark}
main{display:grid;gap:.9rem;width:22rem;max-width:calc(100vw - 2rem);padding:1.5rem}
h1{font-size:1.3rem;margin:0}
p{margin:0;line-height:1.45}
label{display:grid;gap:.25rem}
input{font:inherit;padding:.5rem}
button{font:inherit;padding:.5rem 1rem}
.row{display:flex;flex-wrap:wrap;gap:.5rem;justify-content:flex-end}
.said{color:#b00020;min-height:1.25em}
@media (prefers-color-scheme: dark){.said{color:#ff8a80}}
</style>
<body>
<main></main>
<script>
(() => {
    const main = document.querySelector("main");
    const path = location.pathname;
    const base = path.slice(0, path.lastIndexOf("/") + 1);
    const resetting = path.endsWith("/reset");
    const token = location.hash.slice(1);
    // (Another link opened where this page is changes its fragment alone,
    // which loads nothing: the page starts again for it.)
    addEventListener("hashchange", () => location.reload());
    const title = resetting ? "Set a new password" : "Check your address";
    document.title = title;
    const el = (tag, text, cls) => { const e = document.createElement(tag); if (text !== undefined) e.textContent = text; if (cls) e.className = cls; return e; };
    const show = (...parts) => main.replaceChildren(el("h1", title), ...parts);
    const ask = async (action, body) => {
        try {
            const res = await fetch(base + action, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
            const data = await res.json();
            return data && typeof data === "object" ? data : { ok: false, detail: "the app gave no answer" };
        } catch (_) {
            return { ok: false, detail: "the app could not be reached" };
        }
    };
    if (!token) return show(el("p", "This page is opened by a link mailed to an account's address, and this address holds no such link."));
    const said = el("p", "", "said");
    said.setAttribute("role", "alert");
    const form = el("form");
    form.style.display = "contents";
    const row = el("div", undefined, "row");
    const go = el("button", resetting ? "Set the password" : "Check my address");
    go.type = "submit";
    row.appendChild(go);
    if (resetting) {
        const field = el("label", "A new password, of at least 8 characters");
        const password = el("input");
        password.type = "password";
        password.autocomplete = "new-password";
        field.appendChild(password);
        form.onsubmit = async (ev) => {
            ev.preventDefault();
            const got = await ask("reset", { token, password: password.value });
            if (!got.ok) { said.textContent = got.detail; return; }
            // (Kept where the app's pages read their session.)
            localStorage.setItem("jac_token", got.data.token);
            localStorage.removeItem("jac_name");
            const home = el("a", "Go to " + location.host);
            home.href = "/";
            show(el("p", "Your password is set, and you are signed in. Every other session of the account has ended."), home);
        };
        form.append(field, said, row);
        show(form);
        password.focus();
    } else {
        form.onsubmit = async (ev) => {
            ev.preventDefault();
            const got = await ask("check", { token });
            if (!got.ok) { said.textContent = got.detail; return; }
            show(el("p", "Your address is checked. You can close this page."));
        };
        form.append(said, row);
        show(el("p", "This checks that the address this link was mailed to is yours, for an account at " + location.host + ". If you made no account there, close this page."), form);
    }
})();
</script>
</html>
""";

glob PAGE_HEADERS: dict[str, str] = {
    "Content-Security-Policy": "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
    "X-Frame-Options": "DENY",
    "Cache-Control": "no-store",
};
def:pub auth_route(r: Request) -> Response;
