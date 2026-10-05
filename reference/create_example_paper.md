# Create an example project: a small study, written as an easypaper paper

Writes the same project as
[`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md),
with a short study in it instead of empty sections: the trees of Barro
Colorado Island, Panama, as the vegan package distributes them (`BCI`),
analysed, written up and cited. Every part of a manuscript is there,
written the way the package expects it, to read, render and copy from:

## Usage

``` r
create_example_paper(path, overwrite = FALSE, git = TRUE, open = FALSE)
```

## Arguments

- path:

  Directory to create, as a single non-empty string; `~` is expanded.
  Its base name becomes the name of the `.Rproj` file. A path that
  exists as a file is refused.

- overwrite:

  Write into a directory that already has files in it. `FALSE` (the
  default) refuses, so an existing manuscript is never silently
  overwritten.

- git:

  Initialise a git repository and make the first commit. `TRUE` by
  default: it is local and private, costs a second, and gives the
  manuscript a history from its first line instead of from the day you
  remember to start one. It has nothing to do with GitHub, which is a
  later and separate decision. Needs `git` on the PATH and a configured
  `user.name` / `user.email`; if either is missing, the project is still
  created and you are told what to run.

- open:

  Open the new project in RStudio. Needs an RStudio session and the
  rstudioapi package; outside one, the project is created and a message
  says so.

## Value

The absolute path of the created project, invisibly.

## Details

    manuscript.qmd              title, short title, authors with shared
                                affiliations, the corresponding author
    _sections/01_abstract.qmd   the abstract, and the keywords under it
    _sections/02_introduction   citations in brackets and in the sentence
    _sections/03_methods        the text of the Methods, and a chunk that reads
                                the data from data/ for every analysis
    _sections/04.1_richness     each analysis beside its text, in a file named
    _sections/04.2_composition  after it: a GLM of richness; a PERMANOVA, a
                                PERMDISP and an NMDS of composition;
                                numbers written by inline R, never typed;
                                scientific names written by R, in italics
    _sections/10_figures        two figures: an NMDS with names in italics
    _sections/11_tables         two flextables, with the three rules
    _sections/12.1_suppl        a supplementary figure and table
    _sections/06-09             the statements at the end, filled in
    data/                       the two tables of BCI, as .csv
    references/                 the five references the text cites, one
                                with a species in its title, set in italics
                                by every render; the style is the
                                template's, Journal of Ecology

[`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md)
stays the one to start a paper of your own with: it writes the structure
and nothing else.

It needs one package, vegan: its `BCI` and `BCI.env` data are written
into `data/`, and the analysis uses it. When it is missing, it is
offered for installation – in an interactive session; elsewhere the
function stops and says what to install. The data were collected by
Condit et al. (2002), *Science* 295: 666–669,
[doi:10.1126/science.1066854](https://doi.org/10.1126/science.1066854) :
cite them, not this example, if you use them. The authors of the example
are borrowed from the history of the field – Charles Darwin and Alfred
Russel Wallace, who never wrote it – and their affiliations and emails
are made up.

## See also

[`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md),
for a project of your own.

## Examples

``` r
if (requireNamespace("vegan", quietly = TRUE)) {
  dir <- file.path(tempdir(), "example_paper")
  create_example_paper(dir, git = FALSE)
  list.files(file.path(dir, "data"))
  unlink(dir, recursive = TRUE)
}
#> Example project created: /tmp/RtmpXrpJXp/example_paper
#>   1. open example_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # the study, rendered
#>   The sections are in _sections/: read them to see how each part is written.

if (FALSE) { # \dontrun{
create_example_paper("example_paper", open = TRUE)
# then, in the project:
render_html()
} # }
```
