# Every function of easypaper, with Quarto, on a project in a folder whose
# path has a space and an accent -- the way many users' folders are named.
# R CMD check renders nothing, because CRAN has no Quarto: this is where a
# render that only fails on one system shows up. Run by render.yaml, on
# Windows and macOS, once on the worked example and once on the blank
# template:
#
#   Rscript .github/render-functions.R example
#   Rscript .github/render-functions.R template

library(easypaper)
source(".github/annotate.R")

kind <- commandArgs(TRUE)[1]
if (is.na(kind)) kind <- "example"
# USERPROFILE is the home on Windows; elsewhere it is not set.
home <- file.path(Sys.getenv("USERPROFILE", path.expand("~")), "Documents", "Ana L\u00f3pez P\u00e9rez")
dir.create(home, recursive = TRUE, showWarnings = FALSE)
p <- switch(kind,
  example  = create_example_paper(file.path(home, "mi paper"), git = FALSE),
  template = create_paper(file.path(home, "mi plantilla"),
                          title = "Habitat and ant nuptial flights",
                          authors = c("Ana L\u00f3pez P\u00e9rez", "Roi Santiago"),
                          git = FALSE),
  stop("Give `example` or `template`.", call. = FALSE))
cat("Project:", p, "\n")

failed <- character(0)
# What a step prints -- Quarto's log among it -- is shown as it comes, so a
# step that hangs still says where, and kept, so that a failure can carry its
# end in the annotation, where the error is.
step <- function(label, code) {
  cat("\n==== ", label, "\n", sep = "")
  log <- character(0)
  keep <- function(m) {
    log <<- c(log, conditionMessage(m))
  }
  out <- character(0)
  con <- textConnection("out", "w", local = TRUE)
  sink(con, split = TRUE)
  ok <- withCallingHandlers(
    tryCatch({ force(code); TRUE }, error = function(e) {
      log <<- c(log, paste("FAILED:", conditionMessage(e)))
      FALSE
    }),
    message = keep, warning = keep)
  sink()
  close(con)
  if (!ok) {
    failed <<- c(failed, label)
    annotate(label, c(out, log))
  }
  invisible(ok)
}

step("list_journals",      print(list_journals(p)))
step("add_journal",        add_journal("ecology-letters", path = p))
step("check_title",        check_title(path = p))
step("check_citations",    check_citations(path = p))
step("check_crossrefs",    check_crossrefs(path = p))
step("check_packages",     check_packages(path = p))
step("check_data",         check_data(path = p))
step("sync_licenses",      sync_licenses(path = p))
step("sync_metadata",      sync_metadata(path = p))
step("manuscript_stats",   manuscript_stats(path = p))
step("render_html",        render_html(path = p))
step("render_docx",        render_docx(path = p))
step("render_pdf",         render_pdf(path = p))
step("render_supplementary", render_supplementary(path = p))
step("render_docx, another journal",
     render_docx(journal = "ecology-letters", path = p))
step("render_all",         render_all(path = p))
step("export_code",        export_code(path = p))
step("export_figure_formats", export_figure_formats(path = p))
step("make_submission",    make_submission(path = p))
step("make_submission, signed, PNG",
     make_submission(blind = FALSE, figure_format = "png", label = "signed",
                     path = p))
step("make_preprint",      make_preprint(path = p))
step("italicize_species", {
  bib <- list.files(file.path(p, "references"), "[.]bib$", full.names = TRUE)
  bib <- setdiff(bib, file.path(p, "references", "packages.bib"))[1]
  italicize_species(bib, output = file.path(home, "italic.json"))
})
step("convert_data",
     convert_data(readxl::readxl_example("datasets.xlsx"),
                  to = file.path(p, "data")))
step("clean_cache",        clean_cache(path = p))

cat("\n==== What was written\n")
print(list.files(p, recursive = TRUE, pattern = "[.](docx|pdf|html|zip|tiff|png)$"))

if (length(failed)) {
  stop("Failed on ", kind, ": ", paste(failed, collapse = ", "), call. = FALSE)
}
cat("\nEverything ran on the ", kind, ".\n", sep = "")
