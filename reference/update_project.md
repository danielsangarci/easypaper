# Bring a project's build logic up to the installed easypaper

A project carries its own copy of the build logic – `make.R`, `run.R`,
`R/submission.R`, the Word templates, the citation styles – so it
renders with easypaper uninstalled. The price is that a fix in the
package does not reach a project already written. This is how it does:
the files are refreshed from the installed version, and everything you
wrote is left alone.

## Usage

``` r
update_project(path = ".", dry_run = FALSE)
```

## Arguments

- path:

  The project's root, the folder holding `make.R`. The working directory
  by default, which is the project root once its `.Rproj` is open.

- dry_run:

  List the files that would change, and write nothing.

## Value

Invisibly, a data frame with one row per managed file: `file`, and
`action` – `"update"`, `"add"`, `"append"` (the `.gitignore`) or
`"same"`.

## Details

What it touches is an explicit list, not everything the template has:
`make.R`, `run.R`, `README.md`, `data/README.md`, `R/submission.R`,
`R/crossref_styles.R`, `R/convert_data.R`, `R/renv_setup.R`,
`R/create_metadata.R`, the Word templates in `format/` and the `.csl`
files the template ships in `references_styles/`. Lines the template's
`.gitignore` has and yours lacks are appended; nothing is removed from
it.

What it never touches: `_sections/`, `manuscript.qmd`,
`supplementary.qmd`, `title_page.qmd`, `_quarto.yml`, `references/`,
`data/` apart from its README, `R/setup.R`, `R/trackdown.R`, the
licences, and any `.csl` you added yourself. Nothing is ever deleted.

Two of the managed files are ones you may have edited:
`R/convert_data.R`, whose `.cd_open_formats` list is yours to extend,
and `make.R`, where a default journal is easy to change. Both are
overwritten, and both are accounted for: extensions your copy knew and
the new one does not are named so you can put them back, and the
project's git history holds the rest. That is why the function insists
on a clean working tree: the update is then one commit you can read with
`git diff` and revert file by file. In a project with no repository it
still runs, and keeps the replaced files in a folder under
[`tempdir()`](https://rdrr.io/r/base/tempfile.html) until the session
ends.

`dry_run = TRUE` lists what would change and writes nothing.

Some versions also change what is expected of you: 0.2.0 replaced
`data/raw/` and `data/csv/` with a single `data/`. Those steps involve
your data or your text and are never done for you. They are printed,
when the project needs them, as the list of what is left to do by hand.

The stamp at the top of `make.R` then records both versions: the one
that created the project and the one it was updated to.

## See also

[`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md),
which writes the project in the first place, and
[`add_journal()`](https://danielsangarci.github.io/easypaper/reference/add_journal.md)
for a citation style the template does not ship.

## Examples

``` r
dir <- file.path(tempdir(), "ant_chemistry")
create_paper(dir, git = FALSE)
#> Project created: /tmp/RtmpTrOWs6/ant_chemistry
#>   1. open ant_chemistry.Rproj
#>   2. source("make.R")
#>   3. render_html()      # or see run.R for every command
update_project(dir, dry_run = TRUE)   # written by this version: nothing to do
#> Project written by easypaper 0.3.2; installed: 0.3.2.
#> Every build file already matches: nothing to update.
unlink(dir, recursive = TRUE)
```
