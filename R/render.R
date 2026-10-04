# ---------------------------------------------------------------------------
# Rendering: the manuscript, its supplement, the working .html, the code.
#
# Quarto can also be called directly -- the RStudio Render button, or
# `quarto render` in a terminal -- but then the checks, the licences, the
# italics of the references and the repairs to the .docx are skipped. To
# build something you will send, use these.
# ---------------------------------------------------------------------------

#' Render the manuscript
#'
#' Each render runs the checks first ([checks]), keeps the licences and the
#' deposit's metadata in step with the manuscript, sets the scientific names
#' of the references in italics, renders with Quarto, repairs what Word would
#' refuse to open, and copies every figure to `figures/` as PNG, JPEG and TIFF
#' at 600 dpi. What it writes goes to the project's `output/` folder.
#'
#' * `render_docx()` writes `output/manuscript_<journal>.docx`, on the
#'   project's Word template, and the supplement beside it, as
#'   `render_supplementary()` does.
#' * `render_pdf()` writes `output/manuscript_<journal>.pdf`, its lines
#'   numbered as in the `.docx`, and the supplement beside it as `.pdf`. It needs a LaTeX installation:
#'   `tinytex::install_tinytex()` is enough.
#' * `render_html()` writes `output/manuscript.html`: the working copy, in
#'   seconds instead of minutes. It does not record `renv.lock`, so rendering
#'   an old version to look into something never rewrites your record.
#' * `render_supplementary()` writes the supplement on its own:
#'   `output/supporting_information.docx`, or one file per
#'   supplementary section when there are several (`_sections/12.1_suppl_*.qmd`,
#'   `12.2_suppl_*.qmd` ...). Its own numbering
#'   (Figure S1...), its own Word template and its own reference list.
#' * `render_all()` runs `render_docx()`, `render_pdf()` and
#'   [export_code()], in that order: every document to read, the supplements
#'   included, into `output/`. It does not build a submission: that
#'   is [make_submission()].
#' * `preview()` opens a live preview in the browser, rendered again every
#'   time you save a `.qmd`.
#'
#' The manuscript and its supplement always come out as separate documents,
#' each with its own reference list. That is what a journal asks for, and the
#' only way the tables survive: merging them means handing both to pandoc,
#' which rebuilds the document and loses every column width.
#'
#' The Word templates ship with the package. To use your own, put a file of
#' the same name -- `word_plain_paper_style.docx` for the manuscript,
#' `word_plain_paper_style_supplementary_material.docx` for the supplement,
#' `word_cover_letter.docx` for the letter -- in a `format/` folder in the
#' project; it is used instead.
#'
#' @param journal The citation style, by the name of its `.csl` without the
#'   extension (see [list_journals()]). `NULL`, the default, takes the one the
#'   manuscript declares in its `csl:` line. Naming one here overrides that
#'   for this call only, and changes no file.
#' @param caption_style How figures and tables are named, in their captions
#'   and where the text cites them: `"default"` is what the `crossref:` block
#'   of `_quarto.yml` says (Figure 1. and Table 1. in a new project). The
#'   others are `"abbrev"` (Fig. 1.), `"colon"` (Figure 1:), `"compact"`
#'   (Fig. 1:) and `"nature"` (Figure 1 |), or one you define, under a name
#'   of your choosing, in `caption-styles:` of the `easypaper:` block of
#'   `_quarto.yml`. It does not follow `journal`: a citation style says
#'   nothing about figures or tables.
#' @param suppl_figures `"separate"` (the default) leaves the supplementary
#'   figures and tables in the supplement, and rewrites their citations in the
#'   main text: `@sfig-map` becomes "Figure S1". `"main"` keeps them at the end
#'   of the manuscript instead.
#' @param output_format `"docx"`, `"pdf"` or `"html"`.
#' @param files The supplementary sections to render. `NULL`, the default,
#'   renders every supplementary section: the numbered files of `_sections/`
#'   with `suppl` in their name, `12.1_suppl_material.qmd` in the template.
#' @param blind `TRUE` leaves the authors off the supplement, for one that
#'   travels with a double-blind submission.
#' @param path The project, or any folder inside it. The working directory by
#'   default, which is the project root once its `.Rproj` is open.
#' @return The path of the file written, invisibly: several for
#'   `render_supplementary()` when there are several supplements. `render_all()`
#'   returns the `output/` folder, and `preview()` nothing useful.
#' @seealso [make_submission()] and [make_preprint()] for what you send, and
#'   [checks] for what every render verifies first.
#' @name render
#' @examples
#' \dontrun{
#' # Inside a project, with its .Rproj open:
#' render_html()                            # the working copy
#' render_docx()                            # in the manuscript's own journal
#' render_docx("ecology-letters", "abbrev") # another journal, "Fig. 1."
#' render_pdf()
#' render_supplementary()
#' render_all()                             # all of the above but the .html
#' }
NULL

#' @rdname render
#' @export
render_docx <- function(journal = NULL, caption_style = "default",
                        suppl_figures = "separate", path = ".") {
  .enter_project(path)
  # The supplement is rendered too, and would print the length on its own:
  # it is held back and printed once, here, when both are done.
  outer <- .batch()
  journal <- .resolve_journal(journal)
  f <- .render("docx", journal, caption_style, "docx",
               suppl_figures = suppl_figures)
  dest <- .out(paste0("manuscript_", journal, ".docx"))
  file.rename(f, dest)
  message("Written: ", dest)
  .record_env()
  if (outer) .report_length(force = TRUE)
  invisible(dest)
}

#' @rdname render
#' @export
render_pdf <- function(journal = NULL, caption_style = "default",
                       suppl_figures = "separate", path = ".") {
  .enter_project(path)
  # The supplement is rendered too, and would print the length on its own:
  # it is held back and printed once, here, when both are done.
  outer <- .batch()
  journal <- .resolve_journal(journal)
  f <- .render("pdf", journal, caption_style, "pdf",
               suppl_figures = suppl_figures)
  dest <- .out(paste0("manuscript_", journal, ".pdf"))
  file.rename(f, dest)
  message("Written: ", dest)
  .record_env()
  if (outer) .report_length(force = TRUE)
  invisible(dest)
}

#' @rdname render
#' @export
render_html <- function(journal = NULL, caption_style = "default", path = ".") {
  .enter_project(path)
  journal <- .resolve_journal(journal)
  f <- .render("html", journal, caption_style, "html")
  message("Written: ", f)
  .report_length()
  invisible(f)
}

#' @rdname render
#' @export
render_supplementary <- function(journal = NULL, caption_style = "default",
                                 output_format = "docx", files = NULL,
                                 blind = FALSE, path = ".") {
  .check_flag(blind, "blind")
  .enter_project(path)
  journal <- .resolve_journal(journal)
  csl <- .csl_path(journal)
  .check_quarto()
  ext <- output_format
  if (is.null(files)) files <- .suppl_files()
  if (!length(files)) {
    message("No supplementary document to render.")
    return(invisible(character(0)))
  }
  # Numbering depends on how many files carry FIGURES, not on how many
  # supplementary documents there are: a text-only appendix does not number.
  floats <- .suppl_float_files()
  n      <- length(files)
  # Under "Supporting Information" goes a reference to the paper this belongs
  # to -- authors, title, journal -- because the file is downloaded on its own
  # from the journal's site, with nothing around it to say what it supports.
  reference <- .manuscript_reference(journal, blinded = blind)
  # The wrapper is not in the render: list, so it inherits nothing from
  # _quarto.yml -- bibliography included. Absolute paths, because
  # quarto_render() writes its metadata file in tempdir(); scientific names in
  # italics, like the main text's.
  bib <- .bibliography()
  dests <- character(0)
  tmps  <- character(0)
  # One on.exit for the whole loop: registering it inside would capture the
  # EXPRESSION `input`, which at exit time holds only its last value.
  on.exit(unlink(tmps), add = TRUE)

  for (k in seq_along(files)) {
    # Always a generated wrapper, never supplementary.qmd itself: that file
    # includes no section, and the wrapper puts in the one asked for -- the
    # caller may want only some (make_submission() renders only the TEXT
    # appendices when the figures stay in the main document).
    input <- .build_supplementary(files[k], k, n, fmt = output_format,
                                  blinded = blind,
                                  caption_style = caption_style)
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
      metadata      = c(list(csl = csl, bibliography = bib,
                             crossref = if (is.na(fk)) {
                               crossref_metadata(caption_style)
                             } else {
                               .suppl_crossref(fk, length(floats), caption_style)
                             }),
                        if (is.null(reference)) NULL
                        else list(subtitle = reference)),
      as_job        = FALSE
    )
    if (!file.exists(produced)) {
      stop("Quarto did not leave ", produced, ". Check the log.", call. = FALSE)
    }
    if (identical(ext, "docx")) .repair_docx(produced)
    dest <- .out(if (n == 1L) paste0("supporting_information.", ext)
                 else sprintf("supporting_information_%s.%s",
                              .suppl_name(files[k]), ext))
    if (!file.rename(produced, dest)) {
      stop("Could not move ", produced, " to ", dest, call. = FALSE)
    }
    dests <- c(dests, dest)
    message("Written: ", dest)
  }
  unlink(.p("output", "figures"), recursive = TRUE)
  export_figure_formats(quiet = TRUE)
  .record_env()
  .report_length()
  invisible(dests)
}

#' @rdname render
#' @export
render_all <- function(journal = NULL, caption_style = "default", path = ".") {
  .enter_project(path)
  outer <- .batch()
  journal <- .resolve_journal(journal)
  # Each render writes its supplement beside the manuscript: a
  # render_supplementary() here would only render the .docx one again.
  render_docx(journal, caption_style)
  render_pdf(journal, caption_style)
  export_code()
  message("\nDone. Outputs in output/")
  if (outer) .report_length(force = TRUE)
  invisible(.p("output"))
}

#' @rdname render
#' @export
preview <- function(path = ".") {
  .enter_project(path)
  .check_quarto()
  quarto::quarto_preview(file = .master(), output_format = "html")
}

# --- The common road -----------------------------------------------------------

#' Quarto is an external binary: renv does NOT capture it. Say which one ran.
#' @noRd
.check_quarto <- function() {
  path <- quarto::quarto_path()
  if (is.null(path) || !nzchar(path) || !file.exists(path)) {
    stop("Cannot find the Quarto binary. It ships inside RStudio and ",
         "Positron; otherwise install it from ",
         "https://quarto.org/docs/get-started/ and check the installation ",
         "with `quarto check` in a terminal.", call. = FALSE)
  }
  v <- as.character(quarto::quarto_version())
  message("quarto ", v, " (", path, ")")
  invisible(v)
}

#' Common wrapper. Returns the path of the file produced.
#'
#' The main text comes out WITHOUT the supplementary material and with its
#' citations replaced by their text ("Figure S1"); the supplement comes out
#' beside it, as its own file or files. They are never put back together.
#'
#' @param blinded TRUE drops the author block and the document opens with the
#'   title alone (double-blind review).
#' @param short_title FALSE leaves the short title out, even when the
#'   manuscript has one: a preprint has no running head.
#' @param supplement FALSE leaves the supplement unrendered. Only for the
#'   deliverable builders: make_submission() and make_preprint() render it
#'   themselves, with their own subset of files and their own names, and would
#'   otherwise render it twice.
#' @noRd
.render <- function(fmt, journal, caption_style, ext,
                    blinded = FALSE, suppl_figures = "separate",
                    supplement = TRUE, short_title = TRUE) {
  .csl_path(journal)   # a journal with no style stops here, before any work
  .check_quarto()
  .check_license(); sync_licenses(quiet = TRUE); sync_metadata(quiet = TRUE)
  check_title(quiet = TRUE)
  .sync_readme_title(.p("README.md"), rmarkdown::yaml_front_matter(.master())$title)
  check_packages(); check_citations(); check_crossrefs(); check_data()
  .check_authors()

  # The supplement is rendered on its own, which is the only way it can carry
  # its own reference list: one Quarto render is one citeproc pass and one
  # bibliography.
  #
  # Two exceptions render the manuscript whole: the .html, which is the
  # working preview, and a project with no supplementary section, which has
  # nothing to separate. Every road goes through a copy of manuscript.qmd:
  # the document's own front matter wins over the metadata passed to
  # quarto_render(), and the title block -- the authors on one line, the
  # affiliations under it -- has to be written into it.
  .rendering()
  whole <- identical(fmt, "html") || !length(.suppl_files())
  input <- .build_main_text(journal, caption_style, fmt, blinded = blinded,
                            suppl_figures = suppl_figures, whole = whole,
                            short_title = short_title)
  on.exit(unlink(input), add = TRUE)
  # as_job = FALSE: otherwise RStudio launches it in the background and the
  # function returns before the file exists.
  quarto::quarto_render(input, output_format = fmt, as_job = FALSE)
  produced <- sub("\\.qmd$", paste0(".", ext), input)
  if (whole && file.exists(produced)) {
    # Where the manuscript rendered whole has always been written.
    dest <- .p("output", paste0("manuscript.", ext))
    dir.create(dirname(dest), showWarnings = FALSE)
    if (!file.rename(produced, dest)) {
      stop("Could not move ", produced, " to ", dest, call. = FALSE)
    }
    produced <- dest
  }
  if (identical(ext, "docx")) .repair_docx(produced)

  if (!whole && supplement) {
    # With suppl_figures = "main" the floats are already at the end of the
    # main text, so only the supplementary TEXT is rendered on its own.
    keep <- if (suppl_figures == "main") .suppl_float_files() else character(0)
    render_supplementary(journal, caption_style, output_format = fmt,
                         files = setdiff(.suppl_files(), keep),
                         blind = blinded)
  }
  if (!length(produced) || !file.exists(produced)) {
    stop("The render left no file behind. Check the log.", call. = FALSE)
  }
  # Quarto copies figures/ into output-dir. All three outputs embed their
  # images (the .html through embed-resources), so that copy only confuses:
  # the good ones (600 dpi, the ones the journal wants) are in figures/ at the
  # project root.
  unlink(.p("output", "figures"), recursive = TRUE)
  export_figure_formats(quiet = TRUE)
  produced
}

# --- Scientific names in the references --------------------------------------

.species_done <- new.env(parent = emptyenv())

#' The bibliography a render hands Quarto: the files the manuscript names --
#' or, failing that, _quarto.yml -- as absolute paths, because quarto_render()
#' writes its metadata file in tempdir(), with the scientific names of the
#' titles in italics.
#'
#' The italic copy is a CSL-JSON written in tempdir(); references/ is only
#' read. packages.bib goes as it is: knitr::write_bib() rewrites it during the
#' render itself, and it cites R packages, not organisms. So does a file that
#' cannot be converted -- no pandoc, a .bib pandoc rejects -- with a warning:
#' italics are never worth a failed render.
#'
#' Once per session and per version of the file: render_all() renders four
#' documents, and the list of doubtful names is worth reading once.
#' `italicize-species: false` in the easypaper: block of _quarto.yml hands the
#' files over untouched.
#' @noRd
.bibliography <- function() {
  bib <- .bib_paths()
  if (!isTRUE(.config("italicize-species", TRUE))) return(as.list(bib))
  as.list(vapply(bib, .italic_bibliography, character(1), USE.NAMES = FALSE))
}

#' The bibliography files the manuscript names -- or, failing that,
#' _quarto.yml -- as absolute paths, as they are on disk.
#' @noRd
.bib_paths <- function() {
  bib <- tryCatch(rmarkdown::yaml_front_matter(.master())$bibliography,
                  error = function(e) NULL)
  if (is.null(bib)) bib <- yaml::read_yaml(.p("_quarto.yml"))$bibliography
  bib <- unlist(bib)
  ifelse(grepl("^(/|~|[A-Za-z]:)", bib), path.expand(bib), .p(bib))
}

#' What GBIF and Wikipedia said about each name. Kept in git with the rest of
#' references/: with it every computer renders the same italics, offline, and
#' years from now. Delete it to have every name looked up again.
#' @noRd
.species_cache <- function() .p("references", "species_cache.rds")

#' One file of the bibliography, with its scientific names in italics.
#' @noRd
.italic_bibliography <- function(f) {
  if (basename(f) == "packages.bib" || !file.exists(f) ||
      !tolower(tools::file_ext(f)) %in% c("bib", "json")) {
    return(f)
  }
  out <- file.path(tempdir(), paste0(tools::file_path_sans_ext(basename(f)),
                                     "_italic.json"))
  stamp <- unname(tools::md5sum(f))
  if (identical(.species_done[[f]], stamp) && file.exists(out)) return(out)
  res <- tryCatch(italicize_species(f, out, cache = .species_cache()),
                  error = function(e) {
    warning("The scientific names of ", basename(f), " could not be set in ",
            "italics, so it goes to Quarto as it is: ", conditionMessage(e),
            call. = FALSE, immediate. = TRUE)
    NULL
  })
  if (is.null(res)) return(f)
  # Without a connection some names went unchecked: try again next render.
  if (!isTRUE(attr(res, "offline"))) .species_done[[f]] <- stamp
  out
}

#' Which scientific names of the references go in italics
#'
#' Every render sets the genera and species in the titles of the reference
#' list in italics, and says -- once per session -- which cases it could not
#' settle and what to write in the `.bib` to settle them. This says it again,
#' without rendering. How the names are found is in [italicize_species()].
#'
#' What GBIF and Wikipedia said about each name is kept in
#' `references/species_cache.rds`. Commit it: with it every computer renders
#' the same italics, offline, years from now. Delete it to have every name
#' looked up again. `italicize-species: false` in the `easypaper:` block of
#' `_quarto.yml` turns the italics off.
#'
#' @param path The project, or any folder inside it. The working directory by
#'   default, which is the project root once its `.Rproj` is open.
#' @return The bibliography files a render would hand Quarto, invisibly.
#' @seealso [italicize_species()], the same for any bibliography outside a
#'   project.
#' @export
#' @examples
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir, git = FALSE)
#' # Offline: only the cache answers, and a name it does not know stays in
#' # roman, with a warning. Online, a render looks each new name up once.
#' old <- options(easypaper.species_offline = TRUE)
#' if (rmarkdown::pandoc_available()) try(check_species(dir))
#' options(old)
#' unlink(dir, recursive = TRUE)
check_species <- function(path = ".") {
  .enter_project(path)
  rm(list = ls(.species_done), envir = .species_done)
  invisible(.bibliography())
}

# --- The environment ----------------------------------------------------------

#' Record, in renv.lock, the environment this document came out of.
#'
#' Called by the renders that produce a document somebody else will read, and
#' deliberately NOT by render_html(): the .html is what you render after
#' renv::restore()ing an old environment to look into a reviewer's complaint,
#' and snapshotting there would rewrite your record with the versions you
#' were only visiting.
#'
#' Only the packages the manuscript actually uses, plus their recursive
#' dependencies -- and easypaper itself, which built the documents and which
#' no file of the project names. Silent when nothing changed.
#' @noRd
.record_env <- function() {
  if (!requireNamespace("renv", quietly = TRUE)) return(invisible(NA))
  # renv prints its report straight to the console rather than through
  # message(), so suppressMessages() does not reach it. This is renv's own
  # switch for that.
  old <- options(renv.verbose = FALSE)
  on.exit(options(old), add = TRUE)
  lock <- .p("renv.lock")
  before <- if (file.exists(lock)) unname(tools::md5sum(lock)) else NA_character_
  pkgs <- tryCatch(.analysis_packages(), error = function(e) character(0))
  snap <- function(force = FALSE) {
    suppressMessages(renv::snapshot(project = .p(), packages = pkgs,
                                    prompt = FALSE, force = force))
    TRUE
  }
  ok <- tryCatch(snap(), error = function(e) {
    # renv refuses to write a lockfile it doubts it could restore -- packages
    # from another Bioconductor release, one installed from an unknown
    # source. A record of what did run is still worth more than none, so it
    # is written anyway, and the doubt is passed on.
    if (!grepl("pre-flight validation", conditionMessage(e), fixed = TRUE)) {
      warning("Could not record the environment: ", conditionMessage(e),
              call. = FALSE, immediate. = TRUE)
      return(FALSE)
    }
    forced <- tryCatch(snap(force = TRUE), error = function(e2) {
      warning("Could not record the environment: ", conditionMessage(e2),
              call. = FALSE, immediate. = TRUE)
      FALSE
    })
    if (isTRUE(forced)) {
      warning("renv.lock written, but renv doubts renv::restore() could bring ",
              "every package back -- often packages from another Bioconductor ",
              "release. renv::snapshot() says which.",
              call. = FALSE, immediate. = TRUE)
    }
    forced
  })
  after <- if (file.exists(lock)) unname(tools::md5sum(lock)) else NA_character_
  if (isTRUE(ok) && !identical(before, after)) {
    message("renv.lock updated: it now describes the environment this render ",
            "came out of.")
  }
  invisible(ok)
}

#' Packages that produced something the compendium contains, and easypaper.
#'
#' renv's default scan walks the whole project, so trackdown -- which only
#' syncs drafts with Google Docs -- ends up in the lockfile of a data deposit.
#' The rule here is narrower but not arbitrary: a package belongs in the lock
#' if its output travels. That is the analysis -- manuscript, sections,
#' R/setup.R, R/analysis*.R -- and easypaper, which built the documents, and
#' whose own dependencies bring in what converted the data (readxl, haven)
#' and wrote the metadata (dataspice). renv adds the recursive dependencies of
#' whatever is listed, so nothing breaks.
#' @noRd
.analysis_packages <- function() {
  files <- c(.master(), .p("supplementary.qmd"), .p("title_page.qmd"),
             list.files(.p("_sections"), "[.]qmd$", full.names = TRUE),
             .p("R/setup.R"),
             list.files(.p("R"), "^analysis.*[.]R$", full.names = TRUE))
  files <- files[file.exists(files)]
  p <- tryCatch(sort(unique(renv::dependencies(files, quiet = TRUE)$Package)),
                error = function(e) character(0))
  p <- unique(c(p, "easypaper"))
  setdiff(p, rownames(utils::installed.packages(priority = "base")))
}

# --- Figures ---------------------------------------------------------------------

FIG_FORMATS <- c("png", "jpg", "tiff")

#' Copy every figure to JPEG and TIFF at 600 dpi
#'
#' knitr writes one format per render, PNG, into `figures/png/`. This
#' converts each of them into `figures/jpg/` and `figures/tiff/`, at 600 dpi
#' and with the TIFF compressed losslessly (LZW), which is what journals ask
#' for on acceptance. Converting is faster than rendering three times, and
#' guarantees the three copies are the same figure. Every render does it on
#' its own.
#'
#' JPEG is lossy and a poor choice for line art or figures with text. It is
#' here because some journals require it; if you get to choose, send the
#' TIFF.
#'
#' @param quiet `TRUE` says nothing.
#' @param path The project, or any folder inside it. The working directory by
#'   default, which is the project root once its `.Rproj` is open.
#' @return The PNG files converted, invisibly.
#' @export
#' @examples
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir, git = FALSE)
#' dir.create(file.path(dir, "figures", "png"), recursive = TRUE)
#' grDevices::png(file.path(dir, "figures", "png", "fig-a-1.png"))
#' plot(1:10)
#' invisible(grDevices::dev.off())
#' export_figure_formats(path = dir)
#' list.files(file.path(dir, "figures"), recursive = TRUE)
#' unlink(dir, recursive = TRUE)
export_figure_formats <- function(quiet = FALSE, path = ".") {
  .enter_project(path)
  pngs <- list.files(.p("figures", "png"), "\\.png$", full.names = TRUE)
  if (!length(pngs)) return(invisible(character(0)))

  for (f in setdiff(FIG_FORMATS, "png")) {
    dir.create(.p("figures", f), recursive = TRUE, showWarnings = FALSE)
  }
  for (p in pngs) {
    img <- magick::image_read(p)
    for (f in setdiff(FIG_FORMATS, "png")) {
      out <- .p("figures", f, sub("\\.png$", paste0(".", f), basename(p)))
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

# --- The .docx Word will open ----------------------------------------------------

#' A paragraph with no first-line indent: `w:ind` goes into its properties,
#' before the elements the schema wants after it, or in properties of its own.
#' @noRd
.no_indent <- function(p) {
  p <- gsub("<w:ind [^>]*/>", "", p, perl = TRUE)
  if (!grepl("<w:pPr>", p, fixed = TRUE)) {
    return(sub("^(<w:p(?: [^>]*)?>)", "\\1<w:pPr><w:ind w:firstLine=\"0\"/></w:pPr>",
               p, perl = TRUE))
  }
  after <- "<w:(?:contextualSpacing|mirrorIndents|suppressOverlap|jc|textDirection|textAlignment|textboxTightWrap|outlineLvl|divId|cnfStyle|rPr|sectPr|pPrChange)[ />]|</w:pPr>"
  m <- regexpr(after, p, perl = TRUE)
  paste0(substr(p, 1L, m - 1L), '<w:ind w:firstLine="0"/>',
         substr(p, m, nchar(p)))
}

#' The keywords line under the abstract -- "Keywords: ants, mimicry" --
#' without the first-line indent of the body text. It is written in
#' _sections/, so it reaches Word as any other paragraph; it is found here by
#' its text, as .keywords() finds it.
#' @noRd
.unindent_keywords <- function(xml) {
  m <- gregexpr("(?s)<w:p(?: [^>]*)?>(?:(?!</w:p>).)*</w:p>", xml, perl = TRUE)
  paras <- regmatches(xml, m)[[1]]
  if (!length(paras)) return(xml)
  text <- vapply(paras, function(p) {
    paste(regmatches(p, gregexpr("(?<=<w:t>|<w:t xml:space=\"preserve\">)[^<]*",
                                 p, perl = TRUE))[[1]], collapse = "")
  }, character(1), USE.NAMES = FALSE)
  hit <- grepl("^\\s*key ?words?\\s*[:.]", text, ignore.case = TRUE, perl = TRUE)
  if (!any(hit)) return(xml)
  paras[hit] <- vapply(paras[hit], .no_indent, character(1), USE.NAMES = FALSE)
  regmatches(xml, m) <- list(paras)
  xml
}

#' The Affiliation paragraph style, which affiliations() asks for, based on
#' the template's body text and without its first-line indent. Pandoc writes
#' it based on "BodyText", an id a template saved by a Word in another
#' language does not have ("Textoindependiente"), and the affiliations then
#' fell back to Normal, in another font.
#' @noRd
.affiliation_style <- function(styles) {
  blocks <- regmatches(styles, gregexpr("(?s)<w:style [^>]*>(?:(?!</w:style>).)*</w:style>",
                                        styles, perl = TRUE))[[1]]
  aff <- grep('w:styleId="Affiliation"', blocks, fixed = TRUE, value = TRUE)
  if (length(aff) != 1L || grepl("<w:ind ", aff, fixed = TRUE)) return(styles)
  body <- grep('<w:name w:val="Body Text"', blocks, fixed = TRUE, value = TRUE)
  id <- if (length(body)) sub('(?s)^.*?w:styleId="([^"]+)".*$', "\\1", body[1], perl = TRUE)
        else "Normal"
  new <- gsub('<w:basedOn w:val="[^"]*" ?/>', "", aff, perl = TRUE)
  new <- sub("(<w:name [^>]*/>)",
             paste0('\\1<w:basedOn w:val="', id, '"/>'), new, perl = TRUE)
  # pPr goes before the rPr of the style, when it has one.
  new <- sub("(<w:rPr>|<w:tblPr>|</w:style>)",
             '<w:pPr><w:ind w:firstLine="0"/></w:pPr>\\1', new, perl = TRUE)
  sub(aff, new, styles, fixed = TRUE)
}

#' The width of the text on the page, in twips, read from the document's own
#' section properties. NA when they cannot be read.
#' @noRd
.text_width <- function(xml) {
  # (?s) so the dot crosses newlines: the block is written over several lines.
  sect <- regmatches(xml, regexpr("(?s)<w:sectPr.*?</w:sectPr>", xml, perl = TRUE))
  if (!length(sect)) return(NA_integer_)
  attr_of <- function(tag, a) {
    e <- regmatches(sect, regexpr(paste0("<", tag, "[^>]*>"), sect))
    if (!length(e)) return(NA_integer_)
    v <- regmatches(e, regexpr(paste0(a, '="[0-9]+"'), e))
    if (!length(v)) NA_integer_ else as.integer(gsub("[^0-9]", "", v))
  }
  w <- attr_of("w:pgSz", "w:w")
  l <- attr_of("w:pgMar", "w:left")
  r <- attr_of("w:pgMar", "w:right")
  if (anyNA(c(w, l, r)) || w - l - r <= 0) NA_integer_ else w - l - r
}

#' Close every table cell that ends in a table, and hand Word a file it will
#' open.
#'
#' Quarto wraps each captioned float in a one-cell table, and a flextable goes
#' inside that cell. The cell then ends with a table, and the OOXML schema
#' requires the last thing in a cell to be a paragraph. Word refuses the file:
#' "Word found unreadable content", and what it offers to recover opens
#' read-only. LibreOffice and Google Docs read it without complaining, which
#' is what makes this so easy to ship without noticing.
#'
#' The repair is one empty paragraph before the cell closes, the table grid
#' set to the width the page really has, and no first-line indent on a
#' figure's paragraph. The affiliations and the keywords line lose that indent
#' too: they are lines of a list, not paragraphs of text. Nothing else is
#' touched, and a document that does not need it comes back unchanged.
#' @noRd
.repair_docx <- function(f) {
  if (!file.exists(f)) return(invisible(FALSE))
  parts <- tryCatch(zip::zip_list(f)$filename, error = function(e) NULL)
  if (is.null(parts) || !"word/document.xml" %in% parts) return(invisible(FALSE))

  d <- file.path(tempdir(), paste0("repair_", basename(f)))
  unlink(d, recursive = TRUE)
  utils::unzip(f, exdir = d)
  x <- file.path(d, "word", "document.xml")
  xml <- readChar(x, file.size(x), useBytes = TRUE)

  # </w:tbl>, then any bookmark markers, then the cell closing: the paragraph
  # goes in just before it closes.
  fixed <- gsub("(</w:tbl>)((?:\\s*<w:bookmark(?:Start|End)[^>]*/>)*\\s*)(</w:tc>)",
                "\\1\\2<w:p/>\\3", xml, perl = TRUE, useBytes = TRUE)
  n <- (nchar(fixed, type = "bytes") - nchar(xml, type = "bytes")) / nchar("<w:p/>")

  # Same container, second defect. It declares 100% of the text width and then
  # fixes its grid at pandoc's own default, 5.5 inches, whatever the page is.
  # A figure is sized to the text width, so a 6.5-inch figure went into a
  # 5.5-inch cell and lost an inch off its right edge.
  w <- .text_width(fixed)
  if (!is.na(w)) {
    # The width goes in the middle of the replacement, never right after a
    # backreference: "\\1" followed by a digit reads as group 19.
    fixed <- gsub('<w:tblGrid><w:gridCol w:w="[0-9]+"( ?)/></w:tblGrid>',
                  paste0('<w:tblGrid><w:gridCol w:w="', w, '"\\1/></w:tblGrid>'),
                  fixed, perl = TRUE, useBytes = TRUE)
  }

  # A figure paragraph inherits the body text's first-line indent -- half an
  # inch in this template -- and a figure is drawn as wide as the text column.
  # The indent pushes that half inch off the right edge and Word clips it.
  # `w:ind` goes before `w:jc`, which is where the schema wants it.
  fixed <- gsub(paste0("(<w:pPr>(?:(?!</w:pPr>).)*?)(<w:jc [^>]*/>)",
                       "(</w:pPr><w:r><w:drawing>)"),
                "\\1<w:ind w:firstLine=\"0\"/>\\2\\3", fixed, perl = TRUE)
  fixed <- gsub(paste0("(<w:pPr>(?:(?!</w:pPr>|<w:ind ).)*?)",
                       "(</w:pPr><w:r><w:drawing>)"),
                "\\1<w:ind w:firstLine=\"0\"/>\\2", fixed, perl = TRUE)

  fixed <- .unindent_keywords(fixed)
  s <- file.path(d, "word", "styles.xml")
  styles <- if (file.exists(s)) readChar(s, file.size(s), useBytes = TRUE)
  styled <- if (!is.null(styles)) .affiliation_style(styles)

  if (identical(fixed, xml) && identical(styled, styles)) {
    unlink(d, recursive = TRUE)
    return(invisible(FALSE))
  }
  writeChar(fixed, x, eos = NULL, useBytes = TRUE)
  if (!identical(styled, styles)) writeChar(styled, s, eos = NULL, useBytes = TRUE)
  # mode = "mirror" keeps the folders; "cherry-pick" would flatten them and
  # the .docx would no longer be a .docx. The order is the package's own, so
  # [Content_Types].xml stays first.
  zip::zip(zipfile = f, files = parts, root = d, mode = "mirror")
  unlink(d, recursive = TRUE)
  if (n > 0) {
    message("Repaired ", basename(f), ": ", n, " table cell(s) closed with a ",
            "paragraph, which is what Word needs to open the file.")
  }
  invisible(TRUE)
}

#' The line spacings a submission offers, and what Word writes for each: the
#' height of a line in twentieths of a point, 240 being single.
#' @noRd
LINE_SPACINGS <- c("1" = 240L, "1.5" = 360L, "2" = 480L)

#' @noRd
.check_spacing <- function(x, arg) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) ||
      !as.character(x) %in% names(LINE_SPACINGS)) {
    stop("`", arg, "` must be 1, 1.5 or 2.", call. = FALSE)
  }
  invisible(x)
}

#' Set the line spacing and the line numbers of a .docx already rendered.
#'
#' The spacing is the default paragraph spacing of the document, which every
#' style of the body inherits -- the Word templates set it there: double for
#' the manuscript, 1.5 for the supplement -- so headers, footers and tables
#' that set their own keep it. The line numbers are a property of each
#' section: restarting never, counting every line. NULL leaves either as the
#' template had it.
#' @noRd
.docx_layout <- function(f, line_numbers = NULL, line_spacing = NULL) {
  if (is.null(line_numbers) && is.null(line_spacing)) return(invisible(FALSE))
  if (!file.exists(f)) return(invisible(FALSE))
  parts <- tryCatch(zip::zip_list(f)$filename, error = function(e) NULL)
  if (is.null(parts) || !all(c("word/document.xml", "word/styles.xml") %in% parts)) {
    return(invisible(FALSE))
  }
  d <- file.path(tempdir(), paste0("layout_", basename(f)))
  unlink(d, recursive = TRUE)
  utils::unzip(f, exdir = d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  read  <- function(x) readChar(x, file.size(x), useBytes = TRUE)
  # As bytes: after a substitution with useBytes the text is marked "bytes",
  # and writeChar() refuses to count its characters.
  write <- function(txt, x) writeBin(charToRaw(txt), x)

  if (!is.null(line_spacing)) {
    twips <- LINE_SPACINGS[[as.character(line_spacing)]]
    x <- file.path(d, "word", "styles.xml")
    write(.default_spacing(read(x), twips), x)
  }
  if (!is.null(line_numbers)) {
    x <- file.path(d, "word", "document.xml")
    write(.line_numbers(read(x), isTRUE(line_numbers)), x)
  }
  # As .repair_docx(): "mirror" keeps the folders, and the package's order
  # keeps [Content_Types].xml first.
  zip::zip(zipfile = f, files = parts, root = d, mode = "mirror")
  invisible(TRUE)
}

#' styles.xml with the default paragraph spacing at `twips`, whatever the
#' template had there, or nothing at all.
#' @noRd
.default_spacing <- function(xml, twips) {
  line <- sprintf('w:line="%d" w:lineRule="auto"', twips)
  if (!grepl("<w:pPrDefault", xml, fixed = TRUE)) {
    xml <- sub("(<w:docDefaults[^>]*>)",
               "\\1<w:pPrDefault><w:pPr></w:pPr></w:pPrDefault>", xml,
               perl = TRUE, useBytes = TRUE)
  }
  xml <- sub("<w:pPrDefault/>", "<w:pPrDefault><w:pPr></w:pPr></w:pPrDefault>",
             xml, fixed = TRUE, useBytes = TRUE)
  xml <- sub("(<w:pPrDefault>)(?!\\s*<w:pPr\\b)", "\\1<w:pPr></w:pPr>", xml,
             perl = TRUE, useBytes = TRUE)
  # (?s): a template written with line breaks has them inside the block too.
  m <- regexpr("(?s)<w:pPrDefault>.*?</w:pPrDefault>", xml, perl = TRUE,
               useBytes = TRUE)
  if (m < 0) return(xml)
  block <- regmatches(xml, m)
  new <- if (grepl("<w:spacing ", block, fixed = TRUE)) {
    # The height and its rule go together: an "exact" or "atLeast" rule would
    # read 480 as 24 points.
    b <- gsub(' w:line="[0-9]+"| w:lineRule="[A-Za-z]+"', "", block, perl = TRUE)
    sub("<w:spacing ", paste0("<w:spacing ", line, " "), b, fixed = TRUE)
  } else {
    sub("<w:pPr>", paste0("<w:pPr><w:spacing ", line, "/>"), block, fixed = TRUE)
  }
  regmatches(xml, m) <- new
  xml
}

#' document.xml with the line numbers of every section on or off.
#' @noRd
.line_numbers <- function(xml, on) {
  xml <- gsub("<w:lnNumType[^>]*/>", "", xml, perl = TRUE, useBytes = TRUE)
  if (!on) return(xml)
  # Where the schema wants it: after the page size, margins, paper source and
  # borders, before everything else a section carries.
  num <- '<w:lnNumType w:countBy="1" w:restart="continuous"/>'
  after <- "(?s)(<w:sectPr(?:\\s[^>]*)?(?<!/)>(?:\\s*<w:(?:headerReference|footerReference|footnotePr|endnotePr|type|pgSz|pgMar|paperSrc)\\b[^>]*/>|\\s*<w:pgBorders\\b.*?</w:pgBorders>)*)"
  gsub(after, paste0("\\1", num), xml, perl = TRUE, useBytes = TRUE)
}

# --- The code, for the supplementary material ----------------------------------

#' Write the analysis code as one script
#'
#' Extracts the R code of `R/setup.R` and of every section, in the order the
#' manuscript includes them, into `output/analysis_code.R`, with a header per
#' section. It opens with a table of contents: the line each section starts
#' on, and the labels of its chunks, so each analysis is found at a glance --
#' the richness model in Results, part 1, say. Beside it goes `output/sessionInfo.txt`, with the versions of R,
#' of every package and of Quarto, and a copy of `renv.lock` when there is
#' one. [render_all()] and [make_submission()] run it on their own; the
#' submission compendium carries what it writes.
#'
#' @param path The project, or any folder inside it. The working directory by
#'   default, which is the project root once its `.Rproj` is open.
#' @return The path of `analysis_code.R`, invisibly.
#' @export
#' @examples
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir, git = FALSE)
#' export_code(dir)
#' list.files(file.path(dir, "output"))
#' unlink(dir, recursive = TRUE)
export_code <- function(path = ".") {
  .enter_project(path)
  out <- .out("analysis_code.R")

  blocks <- list()
  .block <- function(title, lines, what = NULL) {
    blocks[[length(blocks) + 1L]] <<- list(title = title, lines = lines,
                                           what = what)
  }

  if (file.exists(.p("R/setup.R"))) {
    .block("SETUP: R/setup.R", readLines(.p("R/setup.R"), warn = FALSE))
  }

  old <- options(knitr.duplicate.label = "allow")
  on.exit(options(old), add = TRUE)
  for (f in .section_files()) {
    tmp <- tempfile(fileext = ".R")
    knitr::purl(f, output = tmp, documentation = 1L, quiet = TRUE)
    code <- readLines(tmp, warn = FALSE)
    unlink(tmp)
    # Skip sections whose only content is the headers of empty chunks (e.g.
    # the figure/table placeholders before the analysis is written).
    substance <- code[nzchar(trimws(code)) &
                      !grepl("^## ----.*----+\\s*$", code) &
                      !grepl("^#\\|", code)]
    if (!length(substance)) next
    .block(paste("SECTION:", basename(f)), code, .chunk_labels(code))
  }

  # The header, then the contents -- the line each section starts on in this
  # very file, and what it holds -- then the sections.
  head <- c(
    "# =========================================================================",
    "# Analysis code of the manuscript",
    paste("# Written by easypaper::export_code() on", format(Sys.Date())),
    "# DO NOT EDIT BY HAND: it is regenerated from R/setup.R and _sections/*.qmd",
    "# ========================================================================="
  )
  rule <- paste0("# ", strrep("-", 70))
  body <- lapply(blocks, function(b) {
    c("", "", rule, paste0("# ", b$title), rule, "", b$lines)
  })
  n_index <- if (length(blocks)) length(blocks) + 2L else 0L
  # The title of a section is the fourth line of its block.
  starts  <- length(head) + n_index + 4L + cumsum(c(0L, lengths(body)))[seq_along(body)]
  index <- if (length(blocks)) {
    c("#", "# Contents (line in this file, section, chunks):",
      vapply(seq_along(blocks), function(i) {
        b <- blocks[[i]]
        paste0(sprintf("#   %5d  %s", starts[i],
                       sub("^(SETUP|SECTION): ", "", b$title)),
               if (length(b$what)) paste0(" -- ", paste(b$what, collapse = ", ")))
      }, character(1)))
  }
  writeLines(c(head, index, unlist(body)), out)

  # The exact environment the results were produced in. renv.lock captures the
  # R packages; the Quarto version has to be recorded by hand.
  info <- utils::capture.output(utils::sessionInfo())
  v <- tryCatch(as.character(quarto::quarto_version()),
                error = function(e) "not found")
  writeLines(c(info, "", paste("quarto:", v)), .out("sessionInfo.txt"))
  if (file.exists(.p("renv.lock"))) {
    file.copy(.p("renv.lock"), .out("renv.lock"), overwrite = TRUE)
  }
  message("Written: ", out)
  invisible(out)
}

#' The labels of the chunks in code purl() wrote: their `#| label:` lines,
#' which purl() keeps. Chunks with no label are left out.
#' @noRd
.chunk_labels <- function(code) {
  l <- sub("^#\\|\\s*label:\\s*", "", grep("^#\\|\\s*label:", code, value = TRUE))
  l <- trimws(gsub("[\"']", "", l))
  unique(l[nzchar(l)])
}

#' Clear the knitr cache
#'
#' knitr caches each chunk's results and does not notice when a file in
#' `data/` changes. Run this after changing the data, and the next render
#' runs every chunk again. It deletes `cache/`, `_freeze/` and `.quarto/`,
#' which are regenerable and in `.gitignore`.
#'
#' @param path The project, or any folder inside it. The working directory by
#'   default, which is the project root once its `.Rproj` is open.
#' @return The project's root, invisibly.
#' @export
#' @examples
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir, git = FALSE)
#' clean_cache(dir)
#' unlink(dir, recursive = TRUE)
clean_cache <- function(path = ".") {
  .enter_project(path)
  for (d in c("cache", "_freeze", ".quarto")) {
    unlink(.p(d), recursive = TRUE)
  }
  dir.create(.p("cache"), showWarnings = FALSE)
  message("Cache cleared.")
  invisible(.p())
}
