# guides

The docs the site serves: neojac's documentation tree, the Markdown under the
repository's docs/, with `nav.json` saying their order and their sections.

## NavPage

A page nav.json names: its title, its place in nav.json's order of pages,
and the titles of the sections it is in, outermost first.

## docs_dir

The docs tree: the directory `JAC_WEB_DOCS` names when it is set, else the
repository's docs/ in the checkout this file is in.

## docs_version

The version of neojac a docs tree documents. A release's docs/ has the
release's VERSION file beside it, whose first line is the version; a
checkout's has its `jac.toml`, whose `[project] version` it is. "" when the
tree has neither.
