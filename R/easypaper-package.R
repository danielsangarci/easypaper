#' easypaper: scaffold a reproducible Quarto manuscript
#'
#' [create_paper()] writes the whole directory structure of a reproducible
#' scientific manuscript: the text split into sections, a single entry point
#' that renders it for any journal, and a submission folder holding the
#' blinded manuscript together with a data and code compendium. Three more
#' functions serve a project once it exists: [convert_data()] brings the data
#' into the one folder that publishes, [add_journal()] fetches a citation
#' style the template does not ship, and [update_project()] refreshes the
#' build logic from a newer easypaper without touching what you wrote.
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
#' it. `convert_data()` is the one function that lives in both places: the
#' package exports it, and every project carries an identical copy.
#'
#' @seealso [create_paper()], [convert_data()], [add_journal()],
#'   [update_project()], and `vignette("easypaper")` for a tour.
#' @keywords internal
"_PACKAGE"
