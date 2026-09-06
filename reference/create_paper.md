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

  Directory to create. Its base name becomes the name of the `.Rproj`
  file.

- title:

  Manuscript title, written into the YAML of `manuscript.qmd`. `NULL`
  leaves the placeholder, which `make.R` warns about.

- authors:

  Character vector of author names, in order. The first one is marked as
  the corresponding author. Affiliations are not guessed: fill them in
  `_sections/0_authors.qmd`. `NULL` leaves the placeholders.

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

  Open the new project in RStudio when the session allows it.

## Value

The path of the created project, invisibly.

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

## Examples

``` r
if (FALSE) { # \dontrun{
create_paper("~/papers/ant_chemistry",
             title   = "Chemical mimicry in Maculinea rebeli",
             authors = c("Daniel Sanchez-Garcia", "Second Author"))
} # }
```
