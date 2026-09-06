#' easypaper: scaffold a reproducible Quarto manuscript
#'
#' One function, [create_paper()], writes the whole directory structure of a
#' reproducible scientific manuscript: the text split into sections, a single
#' entry point that renders it for any journal, and a submission folder holding
#' the blinded manuscript together with a data and code compendium.
#'
#' @section What you get:
#' A project, not a document. The text lives in `_sections/*.qmd` and
#' `manuscript.qmd` only lists them; `make.R` renders the journal `.docx`, the
#' preprint `.pdf`, a working `.html` and the supplementary material, each with
#' the citation style of the journal you name. `run.R`, inside the project,
#' lists every command with its arguments explained.
#'
#' @section Where the code lives:
#' The build logic is copied into each project rather than kept in this
#' package. The submission compendium ships `scripts/`, and whoever reproduces
#' your analysis should not need easypaper installed to do it. Once created, a
#' project is self-contained and this package is only the scaffold that made
#' it.
#'
#' @seealso [create_paper()], and `vignette("easypaper")` for a tour.
#' @keywords internal
"_PACKAGE"
