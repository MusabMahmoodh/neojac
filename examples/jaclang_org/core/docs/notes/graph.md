# graph

## DocContainer

What holds pages: a version, and each section in it.

## DocVersion

One version of the docs. It holds nav.json's tree: its sections, nested as
nav.json nests them, and the pages directly in it, all in nav.json's order (the
order of the version's Contains edges and each section's).

## DocSection

A section of nav.json, holding its pages and the sections nested in it.

## DocPage

A page, served at its `path`: its file's path in the docs tree without
".md", and without the file's name for a directory's own page.

## trace_sections

The titles of the sections a page is in, outermost first: what it gathers
climbing the Contains edges from the page to its version.

## page_name

The name a page has in the graph: its file's stem, or "index" for the files
that are their directory's own page (a skill's SKILL.md is its directory's).

## page_path

The path a page is served at below its version, from its file's path in the
docs tree: `language/walkers` for language/walkers.md, `start` for
start/index.md, `skills/x` for skills/x/SKILL.md.

## place_page

Place a page in a version: down the sections of its `trail`, by title,
making each one it does not find.

## collect_tree

Fold a version into the sidebar's tree and its reading order, post-order:
each page and section folds itself on exit, once everything below it has.

## _llms_sections

llms.txt's lines for the tree `nodes` inside the sections `trail`: the
pages directly here under a heading of the trail's titles, then each nested
section under its own.

A page nav.json names outside every section heads itself.

## find_page

The page whose path's segments are `asked`, below a version, or, when no page
has that path, the nearest one: the first, in reading order, of those whose
paths share the most leading segments with it (`reach` of them). It walks the
version depth-first, which is reading order.
