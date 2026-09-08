# Add a journal's citation style to the project

The template ships nine `.csl` files, all from ecology. This fetches any
other from the official CSL repository – a couple of thousand styles,
one per journal or publisher – and puts it in `references_styles/`,
where `render_docx("<journal>")` and `make_submission("<journal>")` look
for it.

## Usage

``` r
add_journal(journal, path = ".", overwrite = FALSE, repo = NULL)
```

## Arguments

- journal:

  The style's name in the repository, with or without `.csl`, or the URL
  of a `.csl` file.

- path:

  The project's root. The working directory by default.

- overwrite:

  Replace a style already in `references_styles/`. `FALSE` (the default)
  leaves it and says so.

- repo:

  Where to fetch from: the official repository by default. Another URL,
  or the path of a local checkout of the repository, to work offline or
  behind a mirror.

## Value

The path of the `.csl` written, invisibly.

## Details

Give the name the repository uses: the file name without `.csl`, lower
case with hyphens, as in `"nature"`, `"plos-one"`, `"apa"` or
`"journal-of-ecology"`. The list is at
<https://github.com/citation-style-language/styles>, and Zotero's style
finder at <https://www.zotero.org/styles> searches it by journal name;
its URLs work here too.

Most journals have a *dependent* style: a few lines of metadata pointing
at the parent whose rules they share. Pandoc cannot follow that pointer,
so the parent's rules are fetched and saved under the name you asked
for, and the message says which parent it was.

Nothing new is installed: base R downloads the file, and it is checked
to be a CSL style before it is kept.

## See also

[`update_project()`](https://danielsangarci.github.io/easypaper/reference/update_project.md),
which refreshes the styles the template ships and leaves the ones added
this way alone.

## Examples

``` r
if (FALSE) { # \dontrun{
add_journal("plos-one")            # then: render_docx("plos-one")
add_journal("journal-of-ecology")
add_journal("https://www.zotero.org/styles/nature")
} # }
```
