# Add a journal's citation style to the project

The template ships one `.csl`, `journal-of-ecology.csl`, as an example.
This fetches any other from the official CSL repository – a couple of
thousand styles, one per journal or publisher – and puts it in the
project's `references/` folder, beside the `.bib`, where
`render_docx("<journal>")` and `make_submission("<journal>")` look for
it.

## Usage

``` r
add_journal(journal, path = ".", overwrite = FALSE, repo = NULL)
```

## Arguments

- journal:

  The style's name in the repository, with or without `.csl`, or the URL
  of a `.csl` file.

- path:

  The project, or any folder inside it. The working directory by
  default, which is the project root once its `.Rproj` is open.

- overwrite:

  Replace a style the project already has. `FALSE` (the default) leaves
  it and says so.

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

[`list_journals()`](https://danielsangarci.github.io/easypaper/reference/list_journals.md)
for the styles a project has.

## Examples

``` r
# Offline, from a local copy of the repository. Here the copy is a folder
# holding a single style, the one every project ships.
dir  <- file.path(tempdir(), "my_paper")
repo <- file.path(tempdir(), "styles")
create_paper(dir, git = FALSE)
#> Project created: /tmp/RtmpyulCis/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
dir.create(repo, showWarnings = FALSE)
file.copy(file.path(dir, "references", "journal-of-ecology.csl"),
          file.path(repo, "my-journal.csl"))
#> [1] TRUE
add_journal("my-journal", path = dir, repo = repo)
#> Added references/my-journal.csl (Journal of Ecology).
#>   render_docx("my-journal") and make_submission("my-journal") now use it.
list_journals(dir)
#> [1] "journal-of-ecology" "my-journal"        
unlink(c(dir, repo), recursive = TRUE)

if (FALSE) { # \dontrun{
# The usual way, from the root of a project. Needs a connection.
add_journal("ecology-letters")     # then: render_docx("ecology-letters")
add_journal("plos-one")
add_journal("https://www.zotero.org/styles/nature")
} # }
```
