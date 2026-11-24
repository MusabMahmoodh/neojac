# corpus

A docs tree read whole: each page as the reader shows it, and what nav.json
says of each page: its title, its place in the order and its sections.

## reader_text

A page's Markdown without the lines of its HTML comments, which are notes to
the docs' own checks (`<!-- example: not checked: ... -->`), not to a reader. A
comment inside a code fence is the code's, and stays.

## bundle_from

The tree at `ddir`, labelled with the version of neojac it documents.
