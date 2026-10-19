# Every function of easypaper on Windows, with Quarto, on a project in a folder
# whose path has a space and an accent -- the way a Windows user's folders are
# named. R CMD check renders nothing, because CRAN has no Quarto: this is where
# a render that only fails on Windows shows up. Run by windows-render.yaml.

library(easypaper)

home <- file.path(Sys.getenv("USERPROFILE"), "Documents", "Ana López Pérez")
dir.create(home, recursive = TRUE, showWarnings = FALSE)
p <- create_example_paper(file.path(home, "mi paper"), git = FALSE)
cat("Project:", p, "\n")

failed <- character(0)
step <- function(label, code) {
  cat("\n==== ", label, "\n", sep = "")
  ok <- tryCatch({ force(code); TRUE }, error = function(e) {
    cat("FAILED: ", conditionMessage(e), "\n", sep = "")
    FALSE
  })
  if (!ok) failed <<- c(failed, label)
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
  stop("Failed on Windows: ", paste(failed, collapse = ", "), call. = FALSE)
}
cat("\nEverything ran on Windows.\n")
