# Create a reproducible Quarto manuscript project

Writes, into `path`, the structure of a reproducible manuscript: the
sections as separate `.qmd` files, the references and the journal's
citation style, `R/setup.R` for the analysis, and the folder for the
data. Nothing else: the functions that render and assemble it –
[`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md),
[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
and the rest – live in this package, so the project holds only the
paper.

## Usage

``` r
create_paper(
  path,
  title = NULL,
  authors = NULL,
  overwrite = FALSE,
  git = TRUE,
  open = FALSE
)
```

## Arguments

- path:

  Directory to create, as a single non-empty string; `~` is expanded.
  Its base name becomes the name of the `.Rproj` file. A path that
  exists as a file is refused.

- title:

  Manuscript title, written into the YAML of `manuscript.qmd`, the one
  place it lives. Quotes and backslashes are escaped for YAML, so a
  LaTeX fragment such as `\textit{Formica}` survives. A vector is joined
  with spaces. The heading of the project's `README.md` follows it.
  `NULL` or `""` leaves the placeholder, which every render warns about.

- authors:

  Character vector of author names, in order, or one comma-separated
  string, which is how the RStudio wizard sends them. The first one is
  marked as the corresponding author. Affiliations are not guessed: each
  author gets a placeholder to fill in, in the `affiliations:` of the
  YAML of `manuscript.qmd` (see
  [`affiliations()`](https://danielsangarci.github.io/easypaper/reference/affiliations.md)),
  and an empty `orcid:` for the ORCID iD. The project's `README.md`
  lists them from the first commit. `NULL` or an empty string leaves the
  template's.

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

    manuscript.qmd       title, authors, journal, and the list of sections
    supplementary.qmd    the supplement, as its own document
    _quarto.yml          formats, and the settings of easypaper
    _sections/           the text, one file per section
    R/setup.R            seed, palette and helpers for the analysis
    data/                the data, in open formats: what gets published
    references/          the .bib you cite from, and the journal styles (.csl)
    LICENSE.txt  LICENSE-CODE.txt  README.md  <name>.Rproj

The `easypaper:` block of `_quarto.yml` records the version of easypaper
that created the project, and every render records the one that built
each document in `renv.lock`, with every other package the paper used:
[`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
brings them back years later.

Every argument is checked before anything is written, so a wrong call
stops with a message naming the argument and leaves no half-made project
behind.

## See also

[`create_example_paper()`](https://danielsangarci.github.io/easypaper/reference/create_example_paper.md)
for the same project with a small study written in it, to see how each
part is written;
[`render_html()`](https://danielsangarci.github.io/easypaper/reference/render.md)
to see what you have,
[`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
to bring the data into the project's `data/` folder, and
[`vignette("easypaper")`](https://danielsangarci.github.io/easypaper/articles/easypaper.md)
for a tour of what the project can do.

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir,
             title   = "Manuscript title here",
             authors = c("Charles Darwin", "Alfred Russel Wallace"),
             git     = FALSE)
#> Project created: /tmp/RtmpyulCis/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
list.files(dir)
#>  [1] "LICENSE-CODE.txt"  "LICENSE.txt"       "R"                
#>  [4] "README.md"         "_quarto.yml"       "_sections"        
#>  [7] "cache"             "data"              "figures"          
#> [10] "manuscript.qmd"    "my_paper.Rproj"    "output"           
#> [13] "references"        "supplementary.qmd"
unlink(dir, recursive = TRUE)

if (FALSE) { # \dontrun{
# A real project, with its git history started for you:
create_paper("my_paper",
             title   = "Manuscript title here",
             authors = c("Charles Darwin", "Alfred Russel Wallace"))
} # }
```
