---
description: Files, bytes an app keeps outside its graph - File as a node's field, making and reading one in a space, a file input's File in a page and its address for an img, how one crosses, what an endpoint accepts (@accepts), who may read one, when a sweep takes one out, the files plugin and where it keeps them, the app's /__jac/files, and what each host does.
keywords: File, accepts, FileError, local_files, JAC_FILES, files.contract, upload, file input, profile picture, attachment
---
# Files

A `File` is bytes an app keeps outside its graph: a picture, an attachment, a recording. A node
holds one as it holds any field, and source names no bucket, no key and no delete. This page says
what a `File` is in a space and in a page, how one crosses, what an endpoint accepts, and when a
file goes.

<!-- example: not checked: a served app's module, with a node its app keeps -->
```jac
node Photo {
    has image: File,
        caption: str;
}

@accepts(most=5000000, kinds=["image/png", "image/jpeg"])
def:prot add_photo(image: File, caption: str) -> Photo {
    made = Photo(image=image, caption=caption);
    root ++> made;
    return made;
}
```

- **A `File` is a value that never changes.** It is three fields: `id`, `size` in bytes, and
  `ctype`, the type its bytes are (`image/png`). A program that wants other bytes makes another
  `File`.
- **The graph is the index.** A node's row keeps the three fields, and the bytes are kept by the
  project's `files` plugin. A file is kept while a kept node holds it. Listing a user's photos is
  walking their graph.
- **It crosses as its fields, never its bytes.** A page that gives an endpoint a `File` sends the
  bytes to the app first, in pieces, and then makes an ordinary small call.
- **`jac.toml` picks what keeps the bytes.** The standard plugin, `local_files`, keeps them in the
  app's data directory.

`File` and `@accepts` are built in: a program says them without importing them.

## In a space

A native or cpython space of a serving app makes a `File` from bytes, or from an iterator of bytes
for a file made a piece at a time, and reads one whole or in pieces:

<!-- example: not checked: a served app's module -->
```jac
def:pub report(lines: list[str]) -> File {
    return File("\n".join(lines).encode("utf-8"), "text/plain");
}

def:pub length_of(page: File) -> int {
    total = 0;
    for piece in page.chunks() {
        total += len(piece);
    }
    return total;
}
```

| Member | Gives |
|---|---|
| `File(data, ctype="application/octet-stream")` | A file of `data`, kept whole before it returns |
| `f.id`, `f.size`, `f.ctype` | Its id (64 hex digits), its bytes' count, their type |
| `f.read()` | All of its bytes |
| `f.chunks(most=4194304)` | Its bytes, in pieces of at most `most`, each read as it is asked for |
| `f.url()` | Where its bytes are read from: a path of the app that keeps it |

- **A type is a media type's two names, in lowercase, with no parameters** (`text/plain`, never
  `text/plain; charset=utf-8`). Anything else is `FileError`, which a program imports from
  `stdjac`.
- **For PNG, JPEG, GIF, WebP and PDF the bytes begin as that type's do**, or the file is refused
  (`FileError`: `its bytes are not image/png's`). Every other type is kept as it is said.
- **A `File` that names no kept file raises `LookupError`** where it is read.
- **A file an endpoint makes and no node keeps** is there for the caller to read, for an hour at
  least: a report to download. A sweep then takes it out ([below](#when-a-file-goes)).

Files are kept by a program that serves. A program that is no app's, and an app's program with an
`entry`, keep none: there a `File` is the three fields another app gave it, to hold and to give
back, and making or reading one is a `RuntimeError`.

## In a page

In a browser space a `File` is made from what a file input or a drop gives, a browser's `File` or
`Blob`, or from bytes. It is kept nowhere yet: it is sent when a call carries it.

<!-- example: not checked: a component is a module of a browser space, with JSX -->
```jac
def Picture(photo: Photo | None) -> JsxElement {
    has shown: File | None = photo.image if photo else None;

    async def picked(e: ChangeEvent) {
        chosen = File(e.target.files[0]);
        shown = chosen;
        await add_photo(chosen, "new");
    }

    return <label>
        if shown is not None {
            <img src={shown.url()} alt="" />
        }
        <input type="file" accept="image/png,image/jpeg" onChange={picked} />
    </label>;
}
```

| Member | Gives |
|---|---|
| `File(source, ctype="")` | A file of `source`, of the type `ctype` or the source's own |
| `f.url()` | An address for an `<img>` or a link: the page's own copy of a file it has not sent, and a path of the app for one it was sent or has sent |
| `await f.read()` | All of its bytes, read from the app that keeps it |

- **`url()` works before the file is sent**, so a picture shows the moment it is picked.
- **A call sends the file first.** `add_photo(chosen, "new")` begins the file at the app that has
  `add_photo`'s space, sends its bytes in pieces of the size that app says (its `files` plugin's:
  4 MiB for the standard one), and then calls with the `File` that names them. A `File` sent once
  is sent no more.
- **What the endpoint would refuse is refused before a byte is sent**: a caller it does not admit
  (`:prot`, with no one signed in), a size or a type it does not accept. The call raises
  `RemoteRejected`, as a rejected call does.
- **A phone app's page is the same** (a `hermes` space), with a `Blob` for its source.

## What an endpoint accepts

`@accepts` before an endpoint that takes a `File` says the most bytes each may have and, when it
names any, the types it may be:

<!-- example: not checked: a served app's module -->
```jac
@accepts(most=393216, kinds=["image/jpeg", "image/png", "image/webp"])
def:prot set_avatar(image: File | None) -> Profile {
    mine = [root --> [?:Profile]][0];
    mine.avatar = image;
    return mine;
}
```

- **An endpoint that says nothing takes any type, of at most 16 MiB.**
- **A caller's word is not taken for it.** As a call arrives, each `File` it gives is looked up:
  its size and type are the kept file's whatever the caller said, one that names no kept file
  rejects the call, and so does one the endpoint does not accept.
- **A file sent for a limited endpoint is counted as its calls are** (`@limit`), apart from them.
- `@accepts` is a function's. A walker endpoint takes the 16 MiB of an endpoint that says nothing.

## Who may read a file

Whoever holds its `File`. An id is 64 hex digits made at random, which no one guesses, so a caller
reads the files of the nodes they were sent, as they read those nodes' fields. An endpoint that
should not show a picture does not send its node.

The app sends a file's bytes with the type it was kept as, told to be taken as no other
(`nosniff`) and to run nothing. A PNG, a JPEG, a GIF, a WebP, an AVIF, common audio and video, a
PDF and plain text are shown where their address is opened; every other type is saved.

## When a file goes

`sweep()` (from `stdjac`, [An app's data](data.md)) takes out the kept rows no root leads to, and
then every file that no kept row holds and that was left long enough:

| A file | Is left |
|---|---|
| Whole, and held by no kept node or edge | An hour: time for the call that keeps a file just sent, and for a call that is run again |
| Begun, and never finished | A day |

So a profile's old picture goes with the sweep after it is changed. A sweep reads every row that
can hold a `File`, so it is for a quiet hour, from a scheduled function or by hand.

## Where files are kept

The standard `files` plugin, `local_files`, keeps each file's bytes in the app's data directory,
under `files/`, and what it knows of each (its type, its size, when it was begun) in
`files/files.db` beside them. Several programs on one machine may share it.

```toml
[files]
plugin = "local_files"

[files.local_files]
path = "/var/lib/photos"
```

| Setting | Means |
|---|---|
| `path` | The directory. `files` in the app's data directory unless it is said |

A project has one `files` plugin, picked as its program starts (`JAC_FILES`), as its other plugins
are ([Plugins](plugins.md)). A program opens its files as it starts when a kept node or an
endpoint of it holds a `File`, and data it cannot start with is said then, with the rest.

A plugin of the project's own implements `files.contract`'s `Files`: `piece`, `begin`, `append`
at an offset, `finish`, `stat`, `read` of a range, `drop` and `every`. It keeps bytes, and knows
nothing of who may read them or which are still held: that is the runtime's, once, for every
plugin.

**A plugin says how many bytes a piece of a file is** (`piece`), and the runtime holds every
sender to it, a page and a program that makes a `File` alike:

- A piece goes at an offset that is a multiple of that size, and has from one byte to that many.
- So every piece of a file but its last has exactly that many bytes, and a piece with fewer ends
  the file: nothing is written after it.

A directory takes pieces of any size, and `local_files` says 4 MiB. A store that takes a file as
numbered parts with a least size (an object store's multipart upload) says its part's size, and
is given each part whole. The size is at most what the app's transport takes in one request,
16 MiB for the standard one.

## The app's /__jac/files

What a page's runtime asks of its app, which any client may:

| Request | Does |
|---|---|
| `GET /__jac/files/<id>` | The file's bytes, or the range `Range` asks for (206). `HEAD` likewise. 404 for an id that names no whole file |
| `POST /__jac/files?for=<space>/<module>/<name>`, a JSON object of `size` and `ctype` | Begins a file for that endpoint. Answers its `id`, and how many bytes a piece of it is (`piece`), as the app's `files` plugin says |
| `POST /__jac/files/<id>?for=...&at=<offset>`, bytes | Writes a piece at `offset`, when that is how many bytes the file has. `offset` is a multiple of `piece`, and the piece has at most `piece` bytes: every piece but the last has exactly that many, and one with fewer ends the file. Answers how many bytes the file has (`size`): where the next piece goes. A piece sent twice is written once |
| `POST /__jac/files/<id>/done?for=...` | The file is whole. Answers the `File` that names it (`id`, `size`, `ctype`) |

Each `POST` answers as a call does: `{"ok": true, "data": ...}`, or `{"ok": false, "kind": ...,
"detail": ...}` with 400 for a file the endpoint does not accept and for a piece at an offset
that is no multiple of `piece`, 401 or 403 for a caller it does not admit, 404 for an endpoint or
a file that is not there, 413 for a piece of more than `piece` bytes, and 429 for a caller past
its limit.

An app that serves a page for a space it does not run sends a file on to the app that runs the
space, as it sends the call on, and answers a request for a file of that space with where it is
(307).

## By host

| Host | A `File` |
|---|---|
| `native` and `cpython`, in a serving app | Is made, kept, read and swept. The spaces an app runs keep their files in one place, so a `File` one made names the same file to the others, and a sweep in one leaves what another's nodes hold |
| `native`, in a program with an `entry` | Is held and given back. Making or reading one is a `RuntimeError` |
| `browser`, `hermes` | Is made from a `Blob` or bytes, sent when it crosses, shown by `url()`, read with `await` |
| `node`, `wasm` | Is refused where it is said (E5090): not built yet |

A native program that gives another app a `File` gives its three fields. The app that answers
holds it to the files it keeps, so the call is rejected unless the two keep their files in one
place.

## What goes wrong

| Symptom | Cause |
|---|---|
| A call is `rejected`: `a file of 500000 bytes is more than the 393216 it takes` | The endpoint's `@accepts` |
| A call is `rejected`: `a File that names no kept file` | The `File` was swept, or was made by another app that keeps its files elsewhere |
| `FileError: its bytes are not image/png's` | The bytes begin as another type's |
| A picture is gone an hour after it was sent | No kept node held it: the endpoint did not keep the `File` it was given |
| A piece is `rejected`: `a piece goes at a multiple of 4194304 bytes: one with fewer is the file's last` | A client of its own sent a piece that is not the last with fewer bytes than the begin's `piece`, and then another |
| `neojac does not support `File` in a node space yet` | A module of a node or wasm space says `File` |
