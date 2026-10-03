# Check a project before rendering it

Every render runs these first, and stops on what would otherwise reach
the document broken. Call them yourself to know before waiting for a
render.

## Usage

``` r
check_citations(path = ".")

check_crossrefs(quiet = FALSE, path = ".")

check_packages(path = ".")

check_title(quiet = FALSE, path = ".")

check_data(quiet = FALSE, path = ".")

check_renv(quiet = FALSE, path = ".")
```

## Arguments

- path:

  The project, or any folder inside it. The working directory by
  default, which is the project root once its `.Rproj` is open.

- quiet:

  `TRUE` keeps the notes to yourself and only stops or warns on what is
  wrong.

## Value

`check_citations()`, `check_crossrefs()` and `check_packages()` return
`TRUE` invisibly and stop with an error naming what is missing.
`check_title()` and `check_data()` return `TRUE` or `FALSE` invisibly,
with a warning when `FALSE`. `check_renv()` returns `TRUE` in sync,
`FALSE` not, `NA` when it cannot tell.

## Details

- `check_citations()`: every `@key` cited in the text has an entry in
  `references/*.bib`. Package citations (`@R-pkg`) are written by the
  render itself, so a new one is only announced.

- `check_crossrefs()`: every `@fig-`, `@tbl-`, `@sfig-`... cited has a
  figure or table with that label, and says which ones exist but are
  never cited – journals ask for every figure to be cited in the text. A
  citation written inside a string of R code counts as cited.

- `check_packages()`: every package the manuscript, its sections and
  `R/setup.R` load with
  [`library()`](https://rdrr.io/r/base/library.html) or
  [`require()`](https://rdrr.io/r/base/library.html) is installed. A
  missing one otherwise surfaces a minute into the render, from inside
  Quarto.

- `check_title()`: the manuscript has a title of its own, not the
  template's. It is written once, in the YAML of `manuscript.qmd`.

- `check_data()`: every file the analysis names is in `data/`, and which
  files there nothing reads – they would travel to the data repository
  all the same. It reports; it never removes.

- `check_renv()`: `renv.lock` is there and matches the library in use.

An e-mail address is not a citation, however it is written: an `@` glued
to a letter or a digit – any letter, accented ones too – is an address,
and `\@` is a literal `@`, which is what RStudio's visual editor writes.
That is pandoc's own rule, and pandoc decides what gets cited.

## See also

[`check_species()`](https://danielsangarci.github.io/easypaper/reference/check_species.md)
for the scientific names of the references, and
[`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md),
which runs every one of these first.

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, title = "Ant colonies", git = FALSE)
#> Project created: /tmp/RtmpPIfBNQ/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
check_citations(dir)
check_crossrefs(path = dir)
#> Note: defined but never cited in the text: fig-richness, fig-abundance, tbl-models, tbl-summary, sfig-map, stbl-raw
check_title(path = dir)
#> Title: Ant colonies
check_data(path = dir)
unlink(dir, recursive = TRUE)
```
