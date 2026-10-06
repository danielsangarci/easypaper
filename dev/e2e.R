# ---------------------------------------------------------------------------
# dev/e2e.R -- the test R CMD check cannot run.
#
#   Rscript dev/e2e.R          (from the root of the package)
#
# The tests in tests/testthat/ check the template and every function short
# of rendering. They cannot render anything: Quarto and LaTeX are not there
# on a CRAN machine or on a bare CI runner, and a render takes minutes.
#
# That gap is where real defects live. Two were found this way and neither
# could have shown up in a check: the supplement rendered to .pdf fell back on
# Quarto's own KOMA-Script defaults and died with "scrartcl.cls not found";
# and it carried no `# References` block, so its bibliography came out at the
# end with no heading -- a supplement reaching a journal ending in bare
# entries.
#
# This script builds a whole paper out of invented material, runs every
# command, and then reads what came out. Run it before publishing a
# version.
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
# The originals live outside data/: the project does not publish them, so it
# does not prescribe a place for them either.
dir.create(file.path(p, "originals"), showWarnings = FALSE)
set.seed(42)
write.csv(data.frame(
  colony     = sprintf("MR-%02d", 1:24),
  site       = rep(c("Sierra Norte", "Valle"), 12),
  treatment  = rep(c("control", "treated"), each = 12),
  richness   = rpois(24, 8),
  head_width = round(rnorm(24, 1.42, 0.12), 2)),
  file.path(p, "originals/colonies.csv"), row.names = FALSE)

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
@article{rufa2020,
  author = {Nest, Ann}, title = {Nest architecture of Formica rufa in managed forests},
  journal = {Insectes Sociaux}, year = {2020}, volume = {67}, pages = {1--9}}
', file = file.path(p, "references", "references.bib"), append = TRUE)
# The .bib is only ever read: the italics go into a copy Quarto is handed.
bib_md5 <- unname(tools::md5sum(file.path(p, "references", "references.bib")))

# The master carries the section headings; a section file carries only prose.
writeLines(c(
  "Social parasitism has been studied since the first censuses",
  "[@holldobler1990]. Earlier analytical work laid the groundwork",
  "[@lovelace1843], and recognition was posed in its modern form by",
  "@turing1950."), file.path(p, "_sections", "02_introduction.qmd"))
writeLines(c(
  "```{r}",
  "#| label: richness-model",
  "colonies <- read.csv(here::here('data/colonies.csv'))",
  "b <- round(coef(lm(richness ~ treatment, data = colonies))[[2]], 2)",
  "```",
  "",
  "Richness was higher in treated colonies (beta = `r b`), as shown in",
  "@fig-richness and summarised in @tbl-models. Effort is in @fig-abundance",
  "and @tbl-summary; the excluded colonies are in @stbl-raw and their",
  "locations in @sfig-map."), file.path(p, "_sections", "04.1_results1.qmd"))
# The supplement must cite something of its own: that is the whole point of
# giving it an independent reference list.
cat("\n\nThe protocol follows the classic census method [@holldobler1990],",
    "\nwith the modification of @lovelace1843, as for wood ants [@rufa2020].\n",
    file = file.path(p, "_sections", "12.1_suppl_material.qmd"), append = TRUE)

setwd(p); on.exit(setwd(pkg), add = TRUE)
ok("the project holds no build logic",
   !file.exists("make.R") && identical(list.files("R"), "setup.R"))

# --- 2. every command ------------------------------------------------------
cat("\n== the commands ==\n")
# The three roads out of an originals folder: a format nothing knows must be
# named rather than dropped in silence, and one that is already open must
# travel byte for byte.
file.create(file.path(p, "originals/spectra.raw"))
writeLines("not really a GeoPackage", file.path(p, "originals/plots.gpkg"))
said_raw <- paste(capture.output(convert_data("originals"), type = "message"),
                  collapse = " ")
run("convert_data()",          convert_data("originals"))
run("check_citations()",       check_citations())
run("check_crossrefs()",       check_crossrefs(quiet = TRUE))
run("check_title()",           check_title(quiet = TRUE))
run("render_html()",           render_html())
run("render_docx()",           render_docx())
run("render_pdf()",            render_pdf())
run("render_supplementary()",  render_supplementary())
run("export_code()",           export_code())
run("render_docx() again",     render_docx())
run("render_all()",            render_all())
# What the deliverables send is built in their own folder: the supplement in
# output/ stays the one render_all() wrote.
own_sup <- file.path(p, c("output/supporting_information_e2e_paper.docx",
                          "output/supporting_information_e2e_paper.pdf"))
own_md5 <- unname(tools::md5sum(own_sup))
run("make_submission()",       make_submission("journal-of-ecology", label = "Test"))
run("make_preprint()",         make_preprint())
ok("make_submission() and make_preprint() leave output/'s supplement alone",
   identical(unname(tools::md5sum(own_sup)), own_md5))
ok("and put theirs in the submission, named after it",
   all(file.exists(file.path(p, c(
     "submission/Test/manuscript/supporting_information_Test.docx",
     "submission/bioRxiv/manuscript/supporting_information_bioRxiv.pdf")))) &&
     !any(file.exists(file.path(p, c(
       "submission/Test/manuscript/supporting_information_e2e_paper.docx",
       "submission/bioRxiv/manuscript/supporting_information_e2e_paper.pdf")))))
# A second submission to the same journal is the next version; the first
# stays as it was sent.
first_main <- file.path(p, "submission/Test/manuscript/main_Test.docx")
first_time <- file.mtime(first_main)
run("make_submission() again", make_submission("journal-of-ecology", label = "Test"))
ok("a second submission goes to Test_v2, its files named after it",
   file.exists(file.path(p, "submission/Test_v2/manuscript/main_Test_v2.docx")))
ok("and the first one is left as it was",
   identical(file.mtime(first_main), first_time))
# From a folder inside the project, and from outside it with `path`.
setwd(file.path(p, "_sections"))
run("render_html() from _sections/", render_html())
setwd(pkg)
run("render_html(path = )",    render_html(path = p))
setwd(p)

# --- 3. what the documents actually say ------------------------------------
cat("\n== the documents ==\n")
main <- plain(file.path(p, "output/manuscript_e2e_paper.docx"))
sub  <- plain(file.path(p, "submission/Test/manuscript/main_Test.docx"))
sup  <- plain(file.path(p, "output/supporting_information_e2e_paper.docx"))

ok("no unresolved cross-reference in the manuscript", has(main, "\\?@") == 0)
ok("the citation to the supplement is baked as a literal",
   has(main, "Table S1") >= 1 && has(main, "Figure S1") >= 1)
ok("the supplement does not travel in the main text",
   has(main, "Legend of supplementary figure") == 0)
ok("the main text carries one reference list, its own",
   sum(grepl("^References$", main)) == 1)
ok("the supplement has its own reference heading",
   any(grepl("^References$", sup)))
ok("and its list is its own, not the manuscript's",
   has(sup, "AKINO") == 0 && has(sup, "HOLLDOBLER|Holldobler") >= 1)

# The words Word sets in italics, run by run.
italic_words <- function(f) {
  x <- paste(readLines(unz(f, "word/document.xml"), warn = FALSE), collapse = "")
  runs <- regmatches(x, gregexpr("<w:r[ >].*?</w:r>", x, perl = TRUE))[[1]]
  runs <- runs[grepl("<w:i ?/>|<w:i w:val=\"(true|1|on)\"", runs)]
  unlist(strsplit(gsub("<[^>]+>", " ", runs), "[[:space:],.]+"))
}
main_i <- italic_words(file.path(p, "output/manuscript_e2e_paper.docx"))
ok("the scientific names of the references are in italics",
   all(c("Maculinea", "rebeli", "Myrmica") %in% main_i))
ok("and so are the supplement's, in its own list",
   all(c("Formica", "rufa") %in% italic_words(file.path(p, "output/supporting_information_e2e_paper.docx"))))
ok("and the submitted main text's",
   all(c("Maculinea", "rebeli") %in%
         italic_words(file.path(p, "submission/Test/manuscript/main_Test.docx"))))
ok("the rest of the title is not",
   !any(c("butterfly", "Chemical", "parasite") %in% main_i))
html <- paste(readLines(file.path(p, "output/manuscript_e2e_paper.html"), warn = FALSE), collapse = " ")
ok("the working .html has them too",
   grepl("<em>(<span[^>]*>)?Maculinea rebeli", html))
ok("the .bib was only read", identical(
   unname(tools::md5sum(file.path(p, "references", "references.bib"))), bib_md5))
ok("what GBIF and Wikipedia said is kept in references/",
   file.exists(file.path(p, "references", "species_cache.rds")))
ok("the inline R result was computed", has(main, "beta = ") == 1)
ok("the blinded main text carries no author name",
   has(sub, "\\bAda\\b") == 0 && has(sub, "\\bAlan\\b") == 0)
ok("the blinded main text carries no supplement", has(sub, "Legend of supplementary") == 0)
# The title is the one part of the title block that stays: a journal expects it
# at the head of the anonymised manuscript. It only shows up with --standalone,
# because pandoc reads a .docx title into metadata rather than into the body --
# which is why the plain() above cannot see it, and why this needs its own read.
titled <- function(f) {
  out <- tempfile(fileext = ".txt")
  system2(rmarkdown::pandoc_exec(),
          c(shQuote(f), "-s", "-t", "plain", "-o", shQuote(out)))
  txt <- readLines(out, warn = FALSE)
  head(txt[nzchar(trimws(txt))], 1)
}
ok("the blinded main text opens with the title",
   grepl("Chemical mimicry", titled(
     file.path(p, "submission/Test/manuscript/main_Test.docx")), fixed = TRUE))
ok("and so does the title page",
   grepl("Chemical mimicry", titled(
     file.path(p, "submission/Test/manuscript/title_Test.docx")), fixed = TRUE))

# The affiliations are written once, under the YAML of manuscript.qmd: the
# signed main text and the title page carry them, the blinded one does not.
tpage <- plain(file.path(p, "submission/Test/manuscript/title_Test.docx"))
ok("the title page carries the affiliations",
   has(tpage, "Institution 1") == 1 && has(tpage, "Correspondence") == 1)
ok("the signed main text carries them too", has(main, "Institution 1") == 1)
ok("the blinded main text carries no affiliation",
   has(sub, "Institution 1") == 0 && has(sub, "Correspondence") == 0)
# The authors on one line, one after another, not one under the other.
standalone <- function(f) {
  out <- tempfile(fileext = ".txt")
  system2(rmarkdown::pandoc_exec(),
          c(shQuote(f), "-s", "-t", "plain", "-o", shQuote(out)))
  readLines(out, warn = FALSE)
}
ok("the .html prints the affiliations once, not Quarto's copy as well",
   has(standalone(file.path(p, "output/manuscript_e2e_paper.html")), "Institution 1") == 1)
ok("the authors are printed on one line",
   any(grepl("Ada Lovelace.*Alan Turing", standalone(
     file.path(p, "output/manuscript_e2e_paper.docx")))) &&
   any(grepl("Ada Lovelace.*Alan Turing", standalone(
     file.path(p, "submission/Test/manuscript/title_Test.docx")))))

# Signed, there is no title page: the main text carries everything it would.
signed <- file.path(p, "submission/Signed/manuscript")
run("make_submission(blind = FALSE)",
    make_submission("journal-of-ecology", label = "Signed", blind = FALSE,
                    line_numbers = FALSE, line_spacing = 1.5))
ok("a signed submission has no title page",
   !file.exists(file.path(signed, "title_Signed.docx")))
docx_part <- function(f, part) {
  d <- tempfile()
  utils::unzip(f, part, exdir = d)
  paste(readLines(file.path(d, part), warn = FALSE), collapse = "")
}
ok("the blinded main text is numbered and double-spaced, by default",
   grepl("<w:lnNumType", docx_part(file.path(p, "submission/Test/manuscript/main_Test.docx"),
                                   "word/document.xml"), fixed = TRUE) &&
   grepl('w:line="480"', docx_part(file.path(p, "submission/Test/manuscript/main_Test.docx"),
                                   "word/styles.xml"), fixed = TRUE))
ok("line_numbers = FALSE and line_spacing = 1.5 reach the signed one",
   !grepl("<w:lnNumType", docx_part(file.path(signed, "main_Signed.docx"),
                                    "word/document.xml"), fixed = TRUE) &&
   grepl('w:line="360"', docx_part(file.path(signed, "main_Signed.docx"),
                                   "word/styles.xml"), fixed = TRUE))
ok("and its main text names the authors and their affiliations",
   has(plain(file.path(signed, "main_Signed.docx")), "Institution 1") == 1 &&
   any(grepl("Ada Lovelace", standalone(file.path(signed, "main_Signed.docx")))))

# A preprint with line numbers and double spacing: LaTeX's lineno has to
# load, and the PDF has to come out.
run("make_preprint(line_numbers = TRUE, line_spacing = 2)",
    make_preprint(label = "Numbered", line_numbers = TRUE, line_spacing = 2,
                  suppl_line_spacing = 1))
ok("a numbered, double-spaced preprint comes out",
   file.exists(file.path(p, "submission/Numbered/manuscript/preprint_Numbered.pdf")))

# Every caption style, written the way its name promises, in all three
# formats. Two defects lived here unseen: LaTeX wrote "Figure 1:" whatever
# the style said, and Quarto dropped the space of " |", so "nature" came out
# as "Figure 1| Text" in the .docx and the .html.
captions <- function(x) {
  x <- gsub(" ", " ", x)
  unique(unlist(regmatches(x, gregexpr("(Figure|Fig\\.|Table) 1( \\||[.:])", x))))
}
want <- list(default = c("Figure 1.", "Table 1."), abbrev = c("Fig. 1.", "Table 1."),
             colon = c("Figure 1:", "Table 1:"), compact = c("Fig. 1:", "Table 1:"),
             nature = c("Figure 1 |", "Table 1 |"))
for (st in names(want)) {
  invisible(capture.output(suppressMessages({
    render_docx(caption_style = st); render_pdf(caption_style = st)
    render_html(caption_style = st)
  })))
  h <- paste(readLines(file.path(p, "output/manuscript_e2e_paper.html"), warn = FALSE), collapse = " ")
  h <- gsub("&nbsp;", " ", gsub("<[^>]+>", "", h))
  got <- list(
    docx = captions(plain(file.path(p, "output/manuscript_e2e_paper.docx"))),
    pdf  = captions(unlist(strsplit(pdftools::pdf_text(
             file.path(p, "output/manuscript_e2e_paper.pdf")), "\n"))),
    html = captions(h))
  for (fmt in names(got)) {
    ok(sprintf("caption style %-7s in the .%-4s: %s", st, fmt, paste(want[[st]], collapse = " ")),
       all(want[[st]] %in% got[[fmt]]))
  }
}

# The manuscript and its supplement are never joined: one document per
# section, in output/ and in the deposit alike.
pdfs <- function(f) tryCatch(qpdf::pdf_length(f), error = function(e) NA_integer_)
ok("the .pdf of the manuscript is the manuscript alone",
   isTRUE(pdfs(file.path(p, "output/manuscript_e2e_paper.pdf")) ==
          pdfs(file.path(p, "submission/bioRxiv/manuscript/preprint_bioRxiv.pdf"))))
ok("and the supplement is a document of its own",
   isTRUE(pdfs(list.files(file.path(p, "submission/bioRxiv/manuscript"),
                          "supporting.*pdf", full.names = TRUE)[1]) > 0))

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
   just(file.path(p, "output/supporting_information_e2e_paper.docx")))
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
write.csv(data.frame(x = 1:3), file.path(p, "data/pilot_2024.csv"),
          row.names = FALSE)
said <- paste(capture.output(check_data(), type = "message"), collapse = " ")
ok("an unread data file is reported", grepl("pilot_2024.csv", said))
ok("a format nothing knows is named, not silently dropped",
   grepl("spectra.raw", said_raw))
ok("and it was not copied into data/",
   !file.exists(file.path(p, "data/spectra.raw")))
ok("a format that is already open is copied, not named", {
  # It is named in the list of files written, so look only at the other list:
  # the one of originals left behind.
  left <- if (grepl("not a format this knows: ", said_raw)) {
    sub("They will not reach.*", "",
        sub(".*not a format this knows: ", "", said_raw))
  } else ""
  file.exists(file.path(p, "data/plots.gpkg")) &&
    !grepl("plots.gpkg", left, fixed = TRUE)
})
ok("and it reached the compendium beside the .csv",
   file.exists(file.path(p, "submission/Test/data_and_code/data/plots.gpkg")))
ok("an extension named in `also` is copied too", {
  file.create(file.path(p, "originals/cloud.las"))
  invisible(capture.output(
    suppressWarnings(convert_data("originals", also = "las")),
    type = "message"))
  file.exists(file.path(p, "data/cloud.las"))
})
ok("the original outside data/ reached data/",
   file.exists(file.path(p, "data/colonies.csv")))
ok("and the original itself was left alone",
   file.exists(file.path(p, "originals/colonies.csv")))
ok("and the compendium holds it flat, not in a subfolder",
   file.exists(file.path(p, "submission/Test/data_and_code/data/colonies.csv")))
ok("and is not removed",
   file.exists(file.path(p, "data/pilot_2024.csv")))
ok("while the one the analysis reads is not mentioned",
   !grepl("colonies.csv", said))

# A shapefile is one dataset spread over several files, and the code only ever
# names the .shp: its companions must not be reported as unread.
for (e in c("shp", "dbf", "shx", "prj")) {
  file.create(file.path(p, paste0("data/sites.", e)))
}
cat("\n# the map comes from here::here('data/sites.shp')\n",
    file = file.path(p, "R/setup.R"), append = TRUE)
said_shp <- paste(capture.output(check_data(), type = "message"), collapse = " ")
ok("the sidecars of a shapefile are not reported as unread",
   !grepl("sites[.](dbf|shx|prj)", said_shp))
ok("but a file nothing reads still is", grepl("pilot_2024.csv", said_shp))
ok("and data/metadata/ is never reported as unread data",
   !grepl("attributes.csv|biblio.csv|creators.csv", said_shp))

# Two originals that want the same name: subfolders are not reproduced, so one
# would overwrite the other without a word.
dir.create(file.path(p, "originals/pilot"), showWarnings = FALSE)
write.csv(data.frame(x = 1), file.path(p, "originals/pilot/colonies.csv"),
          row.names = FALSE)
said_clash <- paste(capture.output(
  suppressWarnings(withCallingHandlers(
    convert_data("originals"),
    warning = function(w) message(conditionMessage(w)))),
  type = "message"), collapse = " ")
ok("two originals wanting one name are reported",
   grepl("pilot/colonies.csv", said_clash) && grepl("both give", said_clash))
ok("and the one already in data/ is not overwritten",
   nrow(utils::read.csv(file.path(p, "data/colonies.csv"))) > 1)

ok("renv.lock recorded", file.exists(file.path(p, "renv.lock")))
ok("and it records easypaper, which built the documents",
   "easypaper" %in% names(jsonlite::read_json(file.path(p, "renv.lock"))$Packages))
ok("no temporary file left behind",
   length(list.files(p, "^tmp_")) == 0)

cat(sprintf("\n%d checks passed, %d failed\n", n_ok, n_ko))
setwd(pkg)
if (n_ko > 0) quit(status = 1)
