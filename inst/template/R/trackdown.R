# ---------------------------------------------------------------------------
# trackdown: uploads the manuscript text to Google Drive so co-authors can
# comment and edit it in Docs, and pulls their changes back.
#
# CHANGED from the Rmarkdown version: this used to point at the master file,
# which only holds the skeleton (the child= / the includes). Co-authors never
# saw the text. It now goes SECTION BY SECTION, which is also how a paper is
# really reviewed: one section each.
#
# CAREFUL with the installation: you need the development branch.
#
#   remotes::install_github("ClaudioZandonella/trackdown")
#
# The other two routes do NOT accept .qmd (check_supported_documents() rejects
# the extension):
#   - CRAN, 1.1.1 (December 2021).
#   - the latest tagged release on GitHub, v1.3.0. Quarto support landed in
#     1.4.0, which was never tagged.
# install_github() without @tag installs the default branch (main), which
# declares 1.5.1 and accepts c("rmd", "rnw", "qmd") in R/utils.R. Verified in
# the source.
#
# The repository has not been touched since May 2023: assume this version is
# the final one. It does not affect rendering, only this synchronisation.
# ---------------------------------------------------------------------------
library(here)
library(trackdown)

GPATH  <- ""   # folder inside your Google Drive, e.g. "papers/richness"
PREFIX <- "manuscript"   # Docs will be named manuscript_2_introduction...

.section_path <- function(section) {
  all_files <- list.files(here("_sections"), "\\.qmd$", full.names = TRUE)
  f <- all_files[startsWith(basename(all_files), section)]
  if (length(f) != 1) {
    stop("Ambiguous or unknown section: ", section, ". Available: ",
         paste(sub("\\.qmd$", "", basename(all_files)), collapse = ", "))
  }
  f
}

.gfile <- function(f) paste0(PREFIX, "_", sub("\\.qmd$", "", basename(f)))

#' First upload of a section. section = "2" or "2_introduction".
td_upload <- function(section, hide_code = TRUE) {
  f <- .section_path(section)
  trackdown::upload_file(file = f, gfile = .gfile(f), gpath = GPATH,
                         hide_code = hide_code)
}

#' Push local changes (overwrites what is on Drive).
td_update <- function(section, hide_code = TRUE) {
  f <- .section_path(section)
  trackdown::update_file(file = f, gfile = .gfile(f), gpath = GPATH,
                         hide_code = hide_code)
}

#' Pull the co-authors' changes back into the local .qmd.
td_download <- function(section) {
  f <- .section_path(section)
  trackdown::download_file(file = f, gfile = .gfile(f), gpath = GPATH)
}

## WARNING: always pull before editing locally, and commit right after
## pulling. That way git shows you exactly what each co-author changed.

## If you would rather have co-authors read the whole typeset paper, send them
## the .docx or the .html from output/ and keep
## trackdown for the sections they are actively editing.
