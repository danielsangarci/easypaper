# ---------------------------------------------------------------------------
# dev/e2e.R -- the test R CMD check cannot run.
#
#   Rscript dev/e2e.R          (from the root of the package)
#
# The tests in tests/testthat/ read the files of the template and check that
# the scaffold is sound. They cannot render anything: Quarto and LaTeX are not
# there on a CRAN machine or on a bare CI runner, and a render takes minutes.
# So they verify the scaffold, never the building.
#
# That gap is where real defects live. Two were found this way and neither
# could have shown up in a check: the supplement rendered to .pdf fell back on
# Quarto's own KOMA-Script defaults and died with "scrartcl.cls not found";
# and it carried no `# References` block, so its bibliography came out at the
# end with no heading -- a supplement reaching a journal ending in bare
# entries.
#
# This script builds a whole paper out of invented material, runs every
# command, and then reads what came out. Run it before publishing a version.
# ---------------------------------------------------------------------------

suppressMessages({
  library(devtools)
})

# --- 0. the toolchain ------------------------------------------------------
# Quarto ships inside RStudio and is not on the PATH of a plain R session.
if (!nzchar(Sys.getenv("QUARTO_PATH")) && !nzchar(Sys.which("quarto"))) {
  cand <- "/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto"
  if (file.exists(cand)) Sys.setenv(QUARTO_PATH = cand)
}
if (requireNamespace("tinytex", quietly = TRUE) && tinytex::is_tinytex()) {
  Sys.setenv(PATH = paste(tinytex::tinytex_root(), "bin",
                          list.files(file.path(tinytex::tinytex_root(), "bin"))[1],
                          sep = "/") |>
               (\(p) paste(p, Sys.getenv("PATH"), sep = ":"))())
}
qv <- tryCatch(as.character(quarto::quarto_version()), error = function(e) NA)
if (is.na(qv)) stop("Quarto not found. Set QUARTO_PATH and run again.", call. = FALSE)
cat("quarto", qv, "| pandoc", as.character(rmarkdown::pandoc_version()), "\n")

n_ok <- 0L; n_ko <- 0L
ok <- function(what, cond) {
  cond <- isTRUE(tryCatch(cond, error = function(e) FALSE))
  if (cond) n_ok <<- n_ok + 1L else n_ko <<- n_ko + 1L
  cat(sprintf("  [%s] %s\n", if (cond) "ok  " else "FAIL", what))
}
run <- function(label, expr) {
  t <- system.time(out <- tryCatch(expr,
    error = function(e) structure(conditionMessage(e), class = "e2e_error")))
  bad <- inherits(out, "e2e_error")
  ok(sprintf("%-28s (%4.1fs)%s", label, t[["elapsed"]],
             if (bad) paste(" --", substr(out, 1, 90)) else ""), !bad)
  invisible(out)
}
# What a .docx actually says, once Word is out of the picture.
plain <- function(f) {
  out <- tempfile(fileext = ".txt")
  system2(rmarkdown::pandoc_exec(), c(shQuote(f), "-t", "plain", "-o", shQuote(out)))
  readLines(out, warn = FALSE)
}
has <- function(txt, pat) sum(grepl(pat, txt, ignore.case = TRUE))

pkg <- normalizePath(".")
suppressMessages(load_all(pkg, quiet = TRUE))
p <- file.path(tempdir(), "e2e_paper")
unlink(p, recursive = TRUE)

# --- 1. a paper made of invented material ----------------------------------
cat("\n== a project with data, citations, figures and tables ==\n")
suppressMessages(create_paper(p, title = "Chemical mimicry in Maculinea rebeli",
                              authors = c("Ada Lovelace", "Alan Turing"),
                              git = FALSE))
set.seed(42)
write.csv(data.frame(
  colony     = sprintf("MR-%02d", 1:24),
  site       = rep(c("Sierra Norte", "Valle"), 12),
  treatment  = rep(c("control", "treated"), each = 12),
  richness   = rpois(24, 8),
  head_width = round(rnorm(24, 1.42, 0.12), 2)),
  file.path(p, "data/raw/colonies.csv"), row.names = FALSE)

cat('
@article{lovelace1843,
  author = {Lovelace, Ada}, title = {Notes on the analytical engine},
  journal = {Taylor\'s Scientific Memoirs}, year = {1843}, volume = {3},
  pages = {666--731}}
@article{turing1950,
  author = {Turing, Alan M.}, title = {Computing machinery and intelligence},
  journal = {Mind}, year = {1950}, volume = {59}, pages = {433--460}}
@book{holldobler1990,
  author = {Holldobler, Bert and Wilson, Edward O.}, title = {The Ants},
  publisher = {Harvard University Press}, year = {1990}}
', file = file.path(p, "references", "references.bib"), append = TRUE)

# The master carries the section headings; a section file carries only prose.
writeLines(c(
  "Social parasitism has been studied since the first censuses",
  "[@holldobler1990]. Earlier analytical work laid the groundwork",
  "[@lovelace1843], and recognition was posed in its modern form by",
  "@turing1950."), file.path(p, "_sections", "2_introduction.qmd"))
writeLines(c(
  "```{r}",
  "#| label: richness-model",
  "colonies <- read.csv(here::here('data/csv/colonies.csv'))",
  "b <- round(coef(lm(richness ~ treatment, data = colonies))[[2]], 2)",
  "```",
  "",
  "Richness was higher in treated colonies (beta = `r b`), as shown in",
  "@fig-richness and summarised in @tbl-models. Effort is in @fig-abundance",
  "and @tbl-summary; the excluded colonies are in @stbl-raw and their",
  "locations in @sfig-map."), file.path(p, "_sections", "4.1_results1.qmd"))
# The supplement must cite something of its own: that is the whole point of
# giving it an independent reference list.
cat("\n\nThe protocol follows the classic census method [@holldobler1990],",
    "\nwith the modification of @lovelace1843.\n",
    file = file.path(p, "_sections", "8_suppl_material.qmd"), append = TRUE)

setwd(p); on.exit(setwd(pkg), add = TRUE)
source("make.R")
source("R/sync_data.R")

# --- 2. every command ------------------------------------------------------
cat("\n== the commands ==\n")
# A format sync_data() cannot convert must be named, not dropped in silence.
file.create(file.path(p, "data/raw/colonies.sqlite"))
said_raw <- paste(capture.output(sync_data(), type = "message"), collapse = " ")
run("sync_data()",             sync_data())
run("check_citations()",       check_citations())
run("check_crossrefs()",       check_crossrefs(quiet = TRUE))
run("check_title()",           check_title(quiet = TRUE))
run("render_html()",           render_html())
run("render_docx()",           render_docx())
run("render_pdf()",            render_pdf())
run("render_supplementary()",  render_supplementary())
run("export_code()",           export_code())
run("render_docx(split=TRUE)", render_docx(split = TRUE))
run("make_all()",              make_all())
run("make_submission()",       make_submission("myrmecological-news", label = "Test"))
run("make_preprint()",         make_preprint())

# --- 3. what the documents actually say ------------------------------------
cat("\n== the documents ==\n")
main <- plain(file.path(p, "output/journal/manuscript_myrmecological-news.docx"))
sub  <- plain(file.path(p, "submission/Test/manuscript/main_Test.docx"))
sup  <- plain(file.path(p, "output/supplementary/supporting_information.docx"))

ok("no unresolved cross-reference in the manuscript", has(main, "\\?@") == 0)
ok("the citation to the supplement is baked as a literal",
   has(main, "Table S1") >= 1 && has(main, "Figure S1") >= 1)
ok("the supplement travels once, not twice",
   has(main, "Legend of supplementary figure") == 1)
ok("two independent reference lists in the merged file",
   sum(grepl("^References$", main)) == 2)
ok("the supplement has its own reference heading",
   any(grepl("^References$", sup)))
ok("and its list is its own, not the manuscript's",
   has(sup, "AKINO") == 0 && has(sup, "HOLLDOBLER|Holldobler") >= 1)
ok("the inline R result was computed", has(main, "beta = ") == 1)
ok("the blinded main text carries no author name",
   has(sub, "\\bAda\\b") == 0 && has(sub, "\\bAlan\\b") == 0)
ok("the blinded main text carries no supplement", has(sub, "Legend of supplementary") == 0)

pdfs <- function(f) tryCatch(qpdf::pdf_length(f), error = function(e) NA_integer_)
merged <- pdfs(file.path(p, "output/preprint/preprint.pdf"))
apart  <- pdfs(file.path(p, "submission/bioRxiv/manuscript/preprint_bioRxiv.pdf")) +
          pdfs(list.files(file.path(p, "submission/bioRxiv/manuscript"),
                          "supporting.*pdf", full.names = TRUE)[1])
ok("the merged .pdf holds both halves", isTRUE(merged == apart))

fig <- list.files(file.path(p, "submission/Test/manuscript/figures"),
                  full.names = TRUE)
ok("standalone figures at 600 dpi",
   length(fig) > 0 &&
     magick::image_info(magick::image_read(fig[1]))$width >= 4200)
ok("the compendium is a valid archive",
   length(zip::zip_list(file.path(p, "submission/Test/data_and_code.zip"))$filename) > 5)
# Line numbering is what a journal wants in the manuscript and what nobody
# wants in a letter. Both come off the same Word template, so the pair is
# checked together: it is the kind of thing that regresses in silence.
lnum <- function(f) any(grepl("lnNumType",
  readLines(unz(f, "word/document.xml"), warn = FALSE)))
ok("the manuscript is line-numbered",
   lnum(file.path(p, "submission/Test/manuscript/main_Test.docx")))
ok("the cover letter is not",
   !lnum(file.path(p, "submission/Test/cover_letter_Test.docx")))

# Three Word templates, three answers to the same question. Justification is
# read from the style the body text is actually written in.
just <- function(f) {
  x <- readLines(unz(f, "word/styles.xml"), warn = FALSE)
  b <- regmatches(paste(x, collapse = ""),
                  regexpr('<w:style[^>]*Textoindependiente.*?</w:style>',
                          paste(x, collapse = ""), perl = TRUE))
  length(b) > 0 && grepl('w:jc w:val="both"', b)
}
ok("the manuscript is not justified",
   !just(file.path(p, "submission/Test/manuscript/main_Test.docx")))
ok("the supplement is justified",
   just(file.path(p, "output/supplementary/supporting_information.docx")))
ok("the cover letter is justified",
   just(file.path(p, "submission/Test/cover_letter_Test.docx")))

# --- the metadata of the deposit -------------------------------------------
meta <- function(f) utils::read.csv(file.path(p, "data/metadata", f),
                                    colClasses = "character")
ok("the deposit's title came from the manuscript",
   identical(trimws(meta("biblio.csv")$title[1]),
             "Chemical mimicry in Maculinea rebeli"))
ok("the keywords came with it", nzchar(trimws(meta("biblio.csv")$keywords[1])))
ok("the authors of the paper became the creators of the data",
   all(c("Ada Lovelace", "Alan Turing") %in% trimws(meta("creators.csv")$name)))
ok("the variables of the data file were listed",
   all(c("colony", "richness", "head_width") %in%
         trimws(meta("attributes.csv")$variableName)))

# The promise that makes it safe to run on every render: it adds, never
# rewrites. A description typed by hand has to survive the next render.
a <- meta("attributes.csv")
a$description[a$variableName == "richness"] <- "Species richness per colony"
utils::write.csv(a, file.path(p, "data/metadata/attributes.csv"),
                 row.names = FALSE, na = "")
n1 <- nrow(a)
invisible(render_html())
ok("a second pass does not duplicate the variables", nrow(meta("attributes.csv")) == n1)
ok("and does not overwrite what you wrote by hand",
   identical(meta("attributes.csv")$description[
     meta("attributes.csv")$variableName == "richness"],
     "Species richness per colony"))

# A .csv from a path you abandoned: it must be named, and it must survive --
# check_data() reports, it never removes.
write.csv(data.frame(x = 1:3), file.path(p, "data/csv/pilot_2024.csv"),
          row.names = FALSE)
said <- paste(capture.output(check_data(), type = "message"), collapse = " ")
ok("an unread data file is reported", grepl("pilot_2024.csv", said))
ok("an unconvertible original is named, not silently dropped",
   grepl("colonies.sqlite", said_raw))
ok("and it was not copied into data/csv/",
   !file.exists(file.path(p, "data/csv/colonies.sqlite")))
ok("the original in raw/ reached data/csv/",
   file.exists(file.path(p, "data/csv/colonies.csv")))
ok("and the compendium holds it flat, not in a subfolder",
   file.exists(file.path(p, "submission/Test/data_and_code/data/colonies.csv")))
ok("and is not removed",
   file.exists(file.path(p, "data/csv/pilot_2024.csv")))
ok("while the one the analysis reads is not mentioned",
   !grepl("colonies.csv", said))

ok("renv.lock recorded", file.exists(file.path(p, "renv.lock")))
ok("no temporary file left behind",
   length(list.files(p, "^tmp_")) == 0)

cat(sprintf("\n%d checks passed, %d failed\n", n_ok, n_ko))
setwd(pkg)
if (n_ko > 0) quit(status = 1)
