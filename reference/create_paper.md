# Create a reproducible Quarto manuscript project

Writes, into `path`, the complete structure of a reproducible
manuscript: the sections as separate `.qmd` files, `make.R` as the
single entry point, the journal styles, the Word templates and the
folders for data, figures and outputs.

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

  Manuscript title, written into the YAML of `manuscript.qmd` and
  `title_page.qmd`. Quotes and backslashes are escaped for YAML, so a
  LaTeX fragment such as `\textit{Formica}` survives. A vector is joined
  with spaces. `NULL` or `""` leaves the placeholder, which `make.R`
  warns about.

- authors:

  Character vector of author names, in order, or one comma-separated
  string, which is how the RStudio wizard sends them. The first one is
  marked as the corresponding author. Affiliations are not guessed: fill
  them in `_sections/0_authors.qmd`. `NULL` or an empty string leaves
  the placeholders.

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

The build logic is **copied into the project**, not kept in this
package. That is deliberate: the submission compendium ships `scripts/`,
and a reviewer reproducing your analysis should not have to install
easypaper to do it. Once created, the project is self-contained and this
package is no longer needed.

The top of the project's `make.R` records the version of easypaper that
wrote the structure. The project never needs the package again, but if
the scaffold changes in the future, the stamp is what tells you which
version produced a project you already have.

Every argument is checked before anything is written, so a wrong call
stops with a message naming the argument and leaves no half-made project
behind.

## See also

[`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
to bring the data into the project's `data/` folder, and
[`vignette("easypaper")`](https://danielsangarci.github.io/easypaper/articles/easypaper.md)
for a tour of what the project can do.

## Examples

``` r
dir <- file.path(tempdir(), "ant_chemistry")
create_paper(dir,
             title   = "Chemical mimicry in Maculinea rebeli",
             authors = c("Ada Lovelace", "Alan Turing"),
             git     = FALSE)
#> Project created: /tmp/RtmpV94JFf/ant_chemistry
#>   1. open ant_chemistry.Rproj
#>   2. source("make.R")
#>   3. render_html()      # or see run.R for every command
list.files(dir)
#>  [1] "LICENSE"             "LICENSE-CODE"        "R"                  
#>  [4] "README.md"           "_quarto.yml"         "_sections"          
#>  [7] "ant_chemistry.Rproj" "cache"               "data"               
#> [10] "figures"             "format"              "make.R"             
#> [13] "manuscript.qmd"      "output"              "references"         
#> [16] "references_styles"   "run.R"               "supplementary.qmd"  
#> [19] "title_page.qmd"     
unlink(dir, recursive = TRUE)

if (FALSE) { # \dontrun{
# A real project, with its git history started for you:
create_paper("~/papers/ant_chemistry",
             title   = "Chemical mimicry in Maculinea rebeli",
             authors = c("Daniel Sanchez-Garcia", "Second Author"))
} # }
```
