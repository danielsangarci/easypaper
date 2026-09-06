# ===========================================================================
# make.R - THE ONLY entry point of the project.
#
#   source("make.R")
#   render_journal("myrmecological-news")   # .docx with journal styles
#   render_preprint()           # .pdf for bioRxiv/EcoEvoRxiv
#   render_supplementary()      # .docx of the supplement, on its own
#   render_html()               # working .html (or live preview())
#   export_code()               # clean .R for the supplementary material
#   make_all()                  # all of the above
#
#   make_submission("myrmecological-news")  # label = "MyrmecologicalNews" for the real thing
#
# Quarto can also be called from the terminal (`quarto render`), but then you
# skip the citation checks and the licence synchronisation. To build for real,
# use these functions.
#
# Every argument -- journal, caption_style, split, suppl_figures, label,
# figure_format, blinded, snapshot -- is explained beside its command in run.R,
# and laid out in tables in the Get started guide:
#   https://danielsangarci.github.io/easypaper/articles/easypaper.html
# ===========================================================================

library(here)
library(quarto)
source(here("R/crossref_styles.R"))
source(here("R/submission.R"))

MASTER    <- here("manuscript.qmd")
SECTIONS  <- here("_sections")
OUTPUT    <- here("output")          # = project: output-dir in _quarto.yml

# output/, figures/ and cache/ are in .gitignore, so they do not exist after a
# clone. They are created here so make_all() works on a freshly cloned copy of
# the template.
for (d in c("output/journal", "output/preprint", "output/supplementary",
            "figures", "cache")) {
  dir.create(here(d), recursive = TRUE, showWarnings = FALSE)
}

# --- Utilities -------------------------------------------------------------

#' CSL files available in references_styles/
list_journals <- function() {
  sub("\\.csl$", "", basename(list.files(here("references_styles"), "\\.csl$")))
}

#' The text files of the manuscript, in the order the master includes them.
#' Read from the {{< include >}} lines of manuscript.qmd rather than from file
#' names, so the number in the prefix can keep meaning the section of the paper
#' (4.1 and 4.2 are the two parts of Results) without driving the order.
.section_files <- function() {
  l <- readLines(MASTER, warn = FALSE)
  inc <- regmatches(l, regexpr("\\{\\{< *include +[^>]+? *>\\}\\}", l))
  f <- here(trimws(gsub("^\\{\\{< *include +|>\\}\\}$", "", inc)))
  missing <- !file.exists(f)
  if (any(missing)) {
    stop("manuscript.qmd includes files that do not exist: ",
         paste(basename(f[missing]), collapse = ", "), call. = FALSE)
  }
  f
}

#' The knitr cache does not notice changes in external files. If you touch
#' data/raw/, run this before rendering.
clean_cache <- function() {
  for (d in c("cache", "_freeze", ".quarto")) {
    unlink(here(d), recursive = TRUE)
  }
  dir.create(here("cache"), showWarnings = FALSE)
  message("Cache cleared.")
}

#' Quarto is an external binary: renv does NOT capture it. Record the version.
.check_quarto <- function() {
  path <- quarto::quarto_path()
  if (is.null(path) || !nzchar(path) || !file.exists(path)) {
    stop("Cannot find the Quarto binary.\n",
         "  macOS:  brew install --cask quarto\n",
         "  or:     https://quarto.org/docs/get-started/\n",
         "Then check the installation with `quarto check` in the terminal.",
         call. = FALSE)
  }
  v <- as.character(quarto::quarto_version())
  message("quarto ", v, " (", path, ")")
  invisible(v)
}

# --- Authors: the manuscript YAML is the single source of truth ------------

TEMPLATE_AUTHORS <- c("First Author name", "Second Author name")

#' Read the author names from the YAML of manuscript.qmd.
.author_names <- function() {
  yml <- rmarkdown::yaml_front_matter(MASTER)
  a <- yml$author
  if (is.null(a)) stop("The YAML of ", basename(MASTER), " has no 'author' field.")
  if (!is.list(a)) a <- as.list(a)
  names_ <- vapply(a, function(x) {
    n <- if (is.list(x)) x[["name"]] else x
    if (is.null(n)) NA_character_ else as.character(n)[1]
  }, character(1))
  # Strip the affiliation marks: "First Author^1,\\*^" -> "First Author"
  names_ <- gsub("\\^[^^]*\\^", "", names_)
  names_ <- trimws(gsub("[\\\\*,]+$", "", trimws(names_)))
  names_ <- names_[!is.na(names_) & nzchar(names_)]
  if (!length(names_)) stop("Could not read any author name from the YAML.")
  names_
}

#' "A", "A & B", "A, B & C"
.format_holders <- function(n) {
  if (length(n) == 1) return(n)
  paste(paste(n[-length(n)], collapse = ", "), "&", n[length(n)])
}

#' Write the copyright holders into LICENSE-CODE and into the README notice,
#' taken from the authors in the YAML. Idempotent: run it as many times as you
#' like. It is called on its own from render_*() and make_all().
sync_licenses <- function(year = format(Sys.Date(), "%Y"), quiet = FALSE) {
  holders <- .format_holders(.author_names())

  # MIT: the copyright line is part of its terms
  f <- here("LICENSE-CODE")
  l <- readLines(f, warn = FALSE)
  i <- grep("^Copyright \\(c\\)", l)[1]
  if (is.na(i)) stop("LICENSE-CODE has no 'Copyright (c) ...' line")
  l[i] <- sprintf("Copyright (c) %s %s", year, holders)
  writeLines(l, f)

  # README: licence notice for the content, between markers.
  # LICENSE (CC BY) is NOT touched: it is the official text and must not be
  # modified.
  f2 <- here("README.md")
  r <- readLines(f2, warn = FALSE)
  a <- grep("<!-- license:start", r, fixed = FALSE)[1]
  b <- grep("<!-- license:end", r, fixed = FALSE)[1]
  if (is.na(a) || is.na(b) || b <= a) {
    stop("Cannot find the license:start / license:end markers in README.md")
  }
  notice <- c(
    sprintf("> (c) %s %s. The text, figures, tables and data of this compendium", year, holders),
    "> are licensed under",
    "> [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)."
  )
  writeLines(c(r[seq_len(a)], notice, r[b:length(r)]), f2)

  if (!quiet) message("Copyright holders: ", holders, " (", year, ")")
  invisible(holders)
}

#' Warn if the YAML still carries the template authors.
.check_license <- function() {
  names_ <- .author_names()
  leftovers <- intersect(names_, TEMPLATE_AUTHORS)
  if (length(leftovers)) {
    warning("The YAML of ", basename(MASTER), " still has template authors (",
            paste(leftovers, collapse = ", "), "). Replace them with the real ",
            "ones: they are where the copyright holders of LICENSE-CODE and of ",
            "the README come from.", call. = FALSE, immediate. = TRUE)
  }
  invisible(length(leftovers) == 0)
}

# --- Pre-render checks -----------------------------------------------------
# Neither broken bibliographic citations nor broken cross-references stop
# Quarto: citeproc only warns on stderr, and a reference with no target is
# written as "?@fig-x" in the final document. A Lua filter is no use for this
# either: Quarto resolves cross-references AFTER user filters, so a filter
# cannot tell a broken one from a good one (verified). Hence the checks live
# here, before rendering, where an error really does stop everything.

CROSSREF_PREFIXES <- c("fig", "tbl", "eq", "sec", "lst", "thm", "lem", "cor",
                       "prp", "cnj", "def", "exm", "exr", "sfig", "stbl")

.bib_keys <- function() {
  bibs <- list.files(here("references"), "\\.bib$", full.names = TRUE)
  keys <- unlist(lapply(bibs, function(f) {
    l <- readLines(f, warn = FALSE)
    m <- regmatches(l, regexpr("^\\s*@[A-Za-z]+\\s*\\{\\s*[^,]+", l))
    sub("^\\s*@[A-Za-z]+\\s*\\{\\s*", "", m)
  }))
  trimws(unique(keys))
}

#' Every @... key in a file, with code and comments already stripped out.
.at_keys <- function(f) {
  txt <- readLines(f, warn = FALSE)
  # Drop the YAML header (e-mail addresses, orcid...)
  if (length(txt) && grepl("^---\\s*$", txt[1])) {
    end <- grep("^---\\s*$", txt)[2]
    if (!is.na(end)) txt <- txt[-seq_len(end)]
  }
  # Drop code chunks (the S4 @ operator is not a citation).
  inside <- cumsum(grepl("^\\s*```", txt)) %% 2 == 1
  txt <- paste(txt[!inside & !grepl("^\\s*```", txt)], collapse = "\n")
  # Drop inline code and HTML comments: pandoc does not cite there.
  txt <- gsub("`[^`]*`", "", txt)
  txt <- gsub("(?s)<!--.*?-->", "", txt, perl = TRUE)

  m <- gregexpr("(?<![A-Za-z0-9_])@[A-Za-z][A-Za-z0-9_:.#$%&+/-]*", txt, perl = TRUE)
  k <- unlist(regmatches(txt, m))
  k <- sub("^@", "", k)
  sub("[.,;:]+$", "", k)                            # trailing punctuation
}

.is_crossref <- function(k) sub("-.*$", "", k) %in% CROSSREF_PREFIXES

#' Figure/table/section labels defined in the manuscript files:
#' "#| label: fig-x" in chunks and "{#sfig-x}" in divs and headers.
.crossref_labels <- function(files) {
  unlist(lapply(files, function(f) {
    txt <- readLines(f, warn = FALSE)
    chunk <- regmatches(txt, regexpr("(?<=^#\\| label: )[A-Za-z0-9_:.-]+", txt, perl = TRUE))
    div <- unlist(regmatches(txt, gregexpr("(?<=\\{#)[A-Za-z0-9_:.-]+", txt, perl = TRUE)))
    c(chunk, div)
  }))
}

#' Check that every cited figure/table exists, and warn about the ones that
#' exist but are never cited (journals require citing all of them in the text).
check_crossrefs <- function(quiet = FALSE) {
  files <- c(MASTER, .section_files())
  cited   <- unique(Filter(.is_crossref, unlist(lapply(files, .at_keys))))
  defined <- unique(Filter(.is_crossref, .crossref_labels(files)))

  missing <- setdiff(cited, defined)
  if (length(missing)) {
    stop("Cross-references with no target: ", paste(missing, collapse = ", "),
         "\n  Either that figure/table does not exist, or the label is misspelled.",
         call. = FALSE)
  }
  orphans <- setdiff(defined, cited)
  if (length(orphans) && !quiet) {
    message("Note: defined but never cited in the text: ",
            paste(orphans, collapse = ", "))
  }
  invisible(TRUE)
}

#' Check that every cited key exists in references/*.bib.
#' Warn when title_page.qmd disagrees with the manuscript.
#'
#' make_submission() rewrites the title page from the master, so what you
#' submit is always right. This only catches the standalone render (the
#' RStudio Render button, or `quarto render`), where that file speaks for
#' itself and would quietly carry a different title.
check_title <- function(quiet = FALSE) {
  tp <- rmarkdown::yaml_front_matter(here("title_page.qmd"))$title
  ms <- rmarkdown::yaml_front_matter(MASTER)$title
  if (!is.null(tp) && !is.null(ms) && !identical(tp, ms)) {
    warning("title_page.qmd says \"", tp, "\" and ", basename(MASTER),
            " says \"", ms, "\". make_submission() uses the manuscript's, but ",
            "rendering title_page.qmd on its own would use the other one.",
            call. = FALSE, immediate. = TRUE)
    return(invisible(FALSE))
  }
  if (!quiet) message("Title page and manuscript agree.")
  invisible(TRUE)
}

check_citations <- function() {
  files <- c(MASTER, .section_files())
  cited <- unique(Filter(Negate(.is_crossref), unlist(lapply(files, .at_keys))))
  if (!length(cited)) return(invisible(TRUE))

  missing <- setdiff(cited, .bib_keys())
  # The R-* keys are written by knitr::write_bib() at the end of the render:
  # the first time you cite a package they are not in packages.bib yet.
  pending <- grep("^R-", missing, value = TRUE)
  missing <- setdiff(missing, pending)

  if (length(pending)) {
    message("Package citations not generated yet (they will appear after the render): ",
            paste(pending, collapse = ", "))
  }
  if (length(missing)) {
    stop("Citations with no entry in references/*.bib: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

# --- Figures: png (native) + jpg + tiff ------------------------------------

#' Is renv.lock there, and does it match the library actually in use?
#'
#' It LOOKS, it does not write. renv::snapshot() is deliberately NOT called
#' automatically on render: the lockfile is a versioned file, and a build step
#' that rewrites your dependency manifest behind your back is how you end up
#' recording a half-installed library, or a package you were only trying out,
#' as the environment of the paper. Recording the environment is a decision,
#' so it stays a command you type.
#'
#' @return TRUE in sync, FALSE not, NA if it cannot be determined.
check_renv <- function(quiet = FALSE) {
  if (!requireNamespace("renv", quietly = TRUE)) {
    if (!quiet) message("renv is not installed: the versions are only recorded ",
                        "in output/supplementary/sessionInfo.txt.")
    return(invisible(NA))
  }
  if (!file.exists(here("renv.lock"))) {
    warning("There is no renv.lock: the submission would go out with no record ",
            "of the package versions. Run renv::init() once (see R/renv_setup.R).",
            call. = FALSE, immediate. = TRUE)
    return(invisible(FALSE))
  }
  # renv::status() compares the lockfile against renv's ISOLATED project
  # library. Without renv::init() there is no such library, and status would
  # report "not synchronized" for every project that simply keeps a lockfile
  # written from the user's own library -- which is how this template uses it.
  if (!file.exists(here("renv/activate.R")) && !dir.exists(here("renv/library"))) {
    if (!quiet) {
      n <- tryCatch(length(jsonlite::read_json(here("renv.lock"))$Packages),
                    error = function(e) NA_integer_)
      message("renv.lock present (", n, " packages), written from your own ",
              "library. make_submission() refreshes it on every submission.")
    }
    return(invisible(NA))
  }
  st <- tryCatch(suppressMessages(renv::status(project = here())),
                 error = function(e) NULL)
  if (is.null(st) || !"synchronized" %in% names(st)) {
    if (!quiet) message("renv.lock present; could not check whether it is in sync.")
    return(invisible(NA))
  }
  if (isTRUE(st$synchronized)) {
    if (!quiet) message("renv.lock in sync.")
    return(invisible(TRUE))
  }
  warning("renv.lock does NOT match the packages in use. See renv::status(); ",
          "record the current state with renv::snapshot() before submitting.",
          call. = FALSE, immediate. = TRUE)
  invisible(FALSE)
}

FIG_FORMATS <- c("png", "jpg", "tiff")

#' Replicate into figures/jpg/ and figures/tiff/ every figure knitr has written
#' into figures/png/. Called on its own at the end of every render.
#'
#' knitr produces one format per render (dev), and re-rendering three times to
#' change it would re-run the whole analysis. Converting is faster and
#' guarantees the three copies are the SAME figure.
#'
#' Warning: JPEG is lossy and a poor choice for line art or figures with text
#' (artefacts around the strokes). It is here because some journals require it;
#' if you get to choose, send the TIFF.
export_figure_formats <- function(quiet = FALSE) {
  src <- here("figures/png")
  pngs <- list.files(src, "\\.png$", full.names = TRUE)
  if (!length(pngs)) return(invisible(character(0)))

  for (f in setdiff(FIG_FORMATS, "png")) {
    dir.create(here("figures", f), recursive = TRUE, showWarnings = FALSE)
  }
  for (p in pngs) {
    img <- magick::image_read(p)
    for (f in setdiff(FIG_FORMATS, "png")) {
      out <- here("figures", f, sub("\\.png$", paste0(".", f), basename(p)))
      # Explicit density: the PNG stores 236 px/cm and some journals check
      # ">= 600 dpi" literally.
      magick::image_write(img, path = out, format = f, density = "600x600",
                          compression = if (f == "tiff") "LZW" else NULL,
                          quality = if (f == "jpg") 95 else NULL)
    }
  }
  if (!quiet) {
    message("Figures: ", length(pngs), " x ", paste(FIG_FORMATS, collapse = "/"),
            " in figures/")
  }
  invisible(pngs)
}

# --- Render ----------------------------------------------------------------

#' Common wrapper. Returns the path of the file produced.
#'
#' @param split if TRUE, the main text comes out WITHOUT the supplementary
#'   material and with its citations replaced by their text ("Figure S1").
#'   This is what make_submission() uses. See R/submission.R.
#' @param blinded if TRUE, the title block is dropped and the document starts
#'   at the Abstract (double-blind review).
.render <- function(fmt, journal, caption_style, ext, split = FALSE,
                    blinded = FALSE, suppl_figures = "separate") {
  csl <- here("references_styles", paste0(journal, ".csl"))
  if (!file.exists(csl)) {
    stop("There is no CSL called '", journal, "'. Available: ",
         paste(list_journals(), collapse = ", "), call. = FALSE)
  }
  .check_quarto()
  .check_license(); sync_licenses(quiet = TRUE)
  check_citations(); check_crossrefs()

  if (split) {
    # Self-contained document: it does not inherit the project configuration,
    # so there is no metadata to pass.
    input <- .build_main_text(journal, caption_style, fmt, blinded = blinded,
                              suppl_figures = suppl_figures)
    on.exit(unlink(input), add = TRUE)
    quarto::quarto_render(input, output_format = fmt, as_job = FALSE)
    produced <- sub("\\.qmd$", paste0(".", ext), input)
  } else {
    quarto::quarto_render(
      input         = MASTER,
      output_format = fmt,
      # Overrides the defaults from _quarto.yml. csl as an absolute path: the
      # metadata file quarto_render() writes lives in tempdir().
      metadata      = list(csl = csl, crossref = crossref_metadata(caption_style)),
      # as_job = FALSE: otherwise RStudio launches it in the background and the
      # function returns before the file exists.
      as_job        = FALSE
    )
    produced <- file.path(OUTPUT, paste0("manuscript.", ext))
  }
  if (!file.exists(produced)) {
    stop("Quarto did not leave ", produced, ". Check the log.", call. = FALSE)
  }
  # Quarto copies figures/ into output-dir. All three outputs embed their
  # images (the .html through embed-resources), so that copy only confuses:
  # the good ones (600 dpi, the ones the journal wants) are in figures/ at the
  # project root.
  unlink(file.path(OUTPUT, "figures"), recursive = TRUE)
  export_figure_formats(quiet = TRUE)
  produced
}

#' @param journal name of a .csl in references_styles/ (see list_journals())
#' @param caption_style default | abbrev | nature | compact (see R/crossref_styles.R)
#' @param split TRUE leaves the supplement out (what the journal wants); FALSE
#'   produces the complete document, which is handier to circulate among
#'   co-authors. With split = TRUE the bibliographies of the main text and of
#'   the supplement are independent.
render_journal <- function(journal = "myrmecological-news", caption_style = "default",
                           split = FALSE, suppl_figures = "separate") {
  f <- .render("docx", journal, caption_style, "docx", split = split,
               suppl_figures = suppl_figures)
  dest <- here("output/journal", paste0("manuscript_", journal, ".docx"))
  file.rename(f, dest)
  message("Written: ", dest)
  invisible(dest)
}

render_preprint <- function(journal = "myrmecological-news", caption_style = "default",
                            split = FALSE, suppl_figures = "separate") {
  f <- .render("pdf", journal, caption_style, "pdf", split = split,
               suppl_figures = suppl_figures)
  dest <- here("output/preprint/preprint.pdf")
  file.rename(f, dest)
  message("Written: ", dest)
  invisible(dest)
}

#' Working HTML: much faster than the .docx for checking results as you go.
render_html <- function(journal = "myrmecological-news", caption_style = "default") {
  f <- .render("html", journal, caption_style, "html")
  message("Written: ", f)
  invisible(f)
}

#' Supplementary material as a standalone document: its own numbering
#' (Figure S1...), its own .docx template and ITS OWN BIBLIOGRAPHY, without the
#' citations of the main text.
#' @param files supplementary documents to render. By default every
#'   _sections/8*suppl*.qmd; make_submission() passes a subset when the figures
#'   are staying in the main document.
render_supplementary <- function(journal = "myrmecological-news", caption_style = "default",
                                 output_format = "docx", files = NULL) {
  csl <- here("references_styles", paste0(journal, ".csl"))
  if (!file.exists(csl)) {
    stop("There is no CSL called '", journal, "'. Available: ",
         paste(list_journals(), collapse = ", "), call. = FALSE)
  }
  .check_quarto()
  ext   <- if (output_format == "docx") "docx" else output_format
  if (is.null(files)) files <- .suppl_files()
  if (!length(files)) {
    message("No supplementary document to render.")
    return(invisible(character(0)))
  }
  # Numbering depends on how many files carry FIGURES, not on how many
  # supplementary documents there are: a text-only appendix does not number.
  floats <- .suppl_float_files()
  n      <- length(files)
  title  <- rmarkdown::yaml_front_matter(MASTER)$title
  # The wrapper is not in the render: list, so it inherits nothing from
  # _quarto.yml -- bibliography included. Absolute paths, because
  # quarto_render() writes its metadata file in tempdir().
  bib <- unlist(yaml::read_yaml(here("_quarto.yml"))$bibliography)
  bib <- as.list(here(bib))
  dests <- character(0)
  tmps  <- character(0)
  # One on.exit for the whole loop: registering it inside would capture the
  # EXPRESSION `input`, which at exit time holds only its last value.
  on.exit(unlink(tmps), add = TRUE)

  for (k in seq_along(files)) {
    # With a single appendix, supplementary.qmd is rendered as it is. With
    # several, one wrapper per file is generated and deleted afterwards.
    # Always a generated wrapper, never supplementary.qmd itself: that file
    # includes one fixed section, and the caller may well be asking for a
    # different one (make_submission() renders only the TEXT appendices when
    # the figures stay in the main document).
    input <- .build_supplementary(files[k], k, n)
    tmps  <- c(tmps, input)
    # The wrapper is NOT in the render: list of _quarto.yml, and Quarto then
    # writes the output next to the input instead of into output-dir.
    produced <- sub("[.]qmd$", paste0(".", ext), input)
    # Position among the files that carry figures, which is what the S1.1
    # prefix counts. A text-only appendix gets the plain block.
    fk <- match(files[k], floats)
    quarto::quarto_render(
      input         = input,
      output_format = output_format,
      metadata      = list(csl = csl, bibliography = bib, subtitle = title,
                           crossref = if (is.na(fk)) crossref_metadata(caption_style)
                                      else .suppl_crossref(fk, length(floats), caption_style)),
      as_job        = FALSE
    )
    if (!file.exists(produced)) {
      stop("Quarto did not leave ", produced, ". Check the log.", call. = FALSE)
    }
    dest <- here("output/supplementary",
                 if (n == 1L) paste0("supporting_information.", ext)
                 else sprintf("supporting_information_%s.%s", .suppl_name(files[k]), ext))
    if (!file.rename(produced, dest)) {
      stop("Could not move ", produced, " to ", dest, call. = FALSE)
    }
    dests <- c(dests, dest)
    message("Written: ", dest)
  }
  unlink(file.path(OUTPUT, "figures"), recursive = TRUE)
  export_figure_formats(quiet = TRUE)
  invisible(dests)
}

#' Live preview: every time you save a .qmd the browser reloads.
#' Ctrl+C / Esc to stop it.
preview <- function() {
  .check_quarto()
  quarto::quarto_preview(file = MASTER, output_format = "html")
}

# --- Clean .R code for the supplementary material --------------------------

#' Extracts the code from setup.R and from ALL sections, in order, and
#' concatenates it into a single annotated script.
export_code <- function() {
  out <- here("output/supplementary/analysis_code.R")

  writeLines(c(
    "# =========================================================================",
    "# Analysis code of the manuscript",
    paste("# Generated automatically by make.R on", format(Sys.Date())),
    "# DO NOT EDIT BY HAND: it is regenerated from R/setup.R and _sections/*.qmd",
    "# ========================================================================="
  ), out)

  .block <- function(title, lines) {
    cat("\n\n# ", strrep("-", 70), "\n# ", title, "\n# ",
        strrep("-", 70), "\n\n", sep = "", file = out, append = TRUE)
    cat(lines, sep = "\n", file = out, append = TRUE)
  }

  .block("SETUP: R/setup.R", readLines(here("R/setup.R"), warn = FALSE))

  old <- options(knitr.duplicate.label = "allow"); on.exit(options(old))
  for (f in .section_files()) {
    tmp <- tempfile(fileext = ".R")
    knitr::purl(f, output = tmp, documentation = 1L, quiet = TRUE)
    code <- readLines(tmp, warn = FALSE)
    # Skip sections whose only content is the headers of empty chunks (e.g.
    # the figure/table placeholders before the analysis is written).
    substance <- code[nzchar(trimws(code)) &
                      !grepl("^## ----.*----+\\s*$", code) &
                      !grepl("^#\\|", code)]
    if (!length(substance)) next
    .block(paste("SECTION:", basename(f)), code)
  }

  # The exact environment the results were produced in. renv.lock captures the
  # R packages; the Quarto version has to be recorded by hand.
  info <- capture.output(sessionInfo())
  v <- tryCatch(as.character(quarto::quarto_version()), error = function(e) "not found")
  writeLines(c(info, "", paste("quarto:", v)),
             here("output/supplementary/sessionInfo.txt"))
  if (file.exists(here("renv.lock"))) {
    file.copy(here("renv.lock"), here("output/supplementary/renv.lock"),
              overwrite = TRUE)
  }
  message("Written: ", out)
  invisible(out)
}

# --- Everything ------------------------------------------------------------

make_all <- function(journal = "myrmecological-news", caption_style = "default") {
  render_journal(journal, caption_style)
  render_preprint(journal, caption_style)
  render_supplementary(journal, caption_style)
  export_code()
  message("\nDone. Outputs in output/")
}
