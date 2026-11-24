# graph.test

A version under `hub` laid out as nav.json lays out a docs tree: a page
outside every section, two sections nested in one whose pages share one
directory, a section with pages before and after a nested one, and a last
section holding a page nav.json does not name.

## test a page's view names its sections and the nearest page stands in for a missing one

A path that names a directory shows its first page in reading order; one
that names nothing shows the nearest page, said to be missing.

A directory's own page is its path's page, though a page in it comes first.

## test llms txt describes neojac and lists the latest version's pages by section

A nested section's heading says the titles of the sections it is in,
and a section's own pages come before the sections nested in it.
