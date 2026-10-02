# ---------------------------------------------------------------------------
# Co-authors in Google Docs, through trackdown.
#
# One section at a time, which is how a paper is really reviewed: one
# section each. The master file only holds the skeleton -- the includes -- so
# uploading it would show co-authors no text at all.
#
# trackdown has to be the development version. CRAN's (1.1.1) and the latest
# tagged release (v1.3.0) refuse .qmd files; Quarto support landed in 1.4.0,
# which was never tagged, and the repository has not moved since May 2023.
# ---------------------------------------------------------------------------

#' Edit a section with co-authors in Google Docs
#'
#' Uploads one section of the manuscript to Google Drive, where co-authors
#' comment and edit it in Google Docs, and brings their changes back. One
#' section at a time: `manuscript.qmd` only holds the includes, so uploading
#' it would show them no text.
#'
#' * `td_upload()` uploads a section for the first time.
#' * `td_update()` overwrites the Google Doc with your local version.
#' * `td_download()` brings the co-authors' edits back into the `.qmd`.
#'
#' Always download before editing locally, and commit right after
#' downloading: git then shows exactly what each co-author changed. If they
#' would rather read the typeset paper, send them the `.docx` from `output/`
#' and keep this for the sections they are actively editing.
#'
#' It needs the development version of trackdown, which reads `.qmd` files:
#' `remotes::install_github("ClaudioZandonella/trackdown")`. The version on
#' CRAN does not.
#'
#' @param section The section, by the start of its file name in `_sections/`:
#'   `"02"` or `"02_introduction"`.
#' @param gpath The folder inside your Google Drive, e.g. `"papers/richness"`.
#'   `NULL`, the default, takes `trackdown-folder:` from the `easypaper:` block
#'   of `_quarto.yml`, or the root of the Drive.
#' @param hide_code `TRUE` (the default) hides the code chunks in the Google
#'   Doc, so co-authors see prose.
#' @param path The project, or any folder inside it. The working directory by
#'   default, which is the project root once its `.Rproj` is open.
#' @return Whatever trackdown returns, invisibly.
#' @name trackdown
#' @examples
#' \dontrun{
#' td_upload("02_introduction")     # first upload
#' td_update("02_introduction")     # overwrite with your local version
#' td_download("02_introduction")   # bring back their edits
#' }
NULL

#' @rdname trackdown
#' @export
td_upload <- function(section, gpath = NULL, hide_code = TRUE, path = ".") {
  .enter_project(path)
  f <- .td_section(section)
  invisible(trackdown::upload_file(file = f, gfile = .td_gfile(f),
                                   gpath = .td_gpath(gpath),
                                   hide_code = hide_code))
}

#' @rdname trackdown
#' @export
td_update <- function(section, gpath = NULL, hide_code = TRUE, path = ".") {
  .enter_project(path)
  f <- .td_section(section)
  invisible(trackdown::update_file(file = f, gfile = .td_gfile(f),
                                   gpath = .td_gpath(gpath),
                                   hide_code = hide_code))
}

#' @rdname trackdown
#' @export
td_download <- function(section, gpath = NULL, path = ".") {
  .enter_project(path)
  f <- .td_section(section)
  invisible(trackdown::download_file(file = f, gfile = .td_gfile(f),
                                     gpath = .td_gpath(gpath)))
}

#' The section's file, after checking trackdown can read it.
#' @noRd
.td_section <- function(section) {
  .check_string(section, "section")
  if (!requireNamespace("trackdown", quietly = TRUE) ||
      utils::packageVersion("trackdown") < "1.4.0") {
    stop("This needs the development version of trackdown, which reads .qmd ",
         "files:\n  remotes::install_github(\"ClaudioZandonella/trackdown\")",
         call. = FALSE)
  }
  all_files <- list.files(.p("_sections"), "\\.qmd$", full.names = TRUE)
  f <- all_files[startsWith(basename(all_files), section)]
  if (length(f) != 1L) {
    stop(if (length(f)) "Ambiguous" else "Unknown", " section: '", section,
         "'. Available: ",
         paste(sub("\\.qmd$", "", basename(all_files)), collapse = ", "),
         call. = FALSE)
  }
  f
}

#' The Google Doc's name: manuscript_02_introduction...
#' @noRd
.td_gfile <- function(f) paste0("manuscript_", sub("\\.qmd$", "", basename(f)))

#' @noRd
.td_gpath <- function(gpath) {
  if (!is.null(gpath)) return(gpath)
  as.character(.config("trackdown-folder", ""))
}
