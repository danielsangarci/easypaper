# easypaper: scaffold a reproducible Quarto manuscript

One function,
[`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md),
writes the whole directory structure of a reproducible scientific
manuscript: the text split into sections, a single entry point that
renders it for any journal, and a submission folder holding the blinded
manuscript together with a data and code compendium.

## What you get

A project, not a document. The text lives in `_sections/*.qmd` and
`manuscript.qmd` only lists them; `make.R` renders the journal `.docx`,
the preprint `.pdf`, a working `.html` and the supplementary material,
each with the citation style of the journal you name. `run.R`, inside
the project, lists every command with its arguments explained.

## Where the code lives

The build logic is copied into each project rather than kept in this
package. The submission compendium ships `scripts/`, and whoever
reproduces your analysis should not need easypaper installed to do it.
Once created, a project is self-contained and this package is only the
scaffold that made it.

## See also

[`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md),
and
[`vignette("easypaper")`](https://danielsangarci.github.io/easypaper/articles/easypaper.md)
for a tour.

## Author

**Maintainer**: Daniel Sanchez-Garcia <danielsangarci@gmail.com>
([ORCID](https://orcid.org/0000-0002-0710-6292)) \[copyright holder\]

Authors:

- Daniel Sanchez-Garcia <danielsangarci@gmail.com>
  ([ORCID](https://orcid.org/0000-0002-0710-6292)) \[copyright holder\]
