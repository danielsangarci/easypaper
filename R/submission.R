# ---------------------------------------------------------------------------
# make_submission() and make_preprint(): the folders that go to a journal, a
# preprint server and a data repository, built out of what is already in the
# project.
#
#   submission/<Journal>/
#     cover_letter_<Journal>.docx      <- dated, titled, signed; NOT overwritten
#     CHECKLIST.md                     <- what has to be done by hand
#     manuscript/
#       title_<Journal>.docx           <- title page, double-blind only
#       main_<Journal>.docx            <- main text, without the supplement
#       supporting_information_<Journal>.docx
#       figures/Figure_1.tiff ...      <- one per figure, 600 dpi, LZW
#     data_and_code/                   <- compendium: data, metadata, code
#     data_and_code.zip
#     data_and_code_blinded/           <- the same, naming nobody: for the
#     data_and_code_blinded.zip           reviewers, double-blind only
#
# Everything here is REGENERABLE except the cover letter.
# ---------------------------------------------------------------------------

#' Build the folder you send to a journal
#'
#' Writes `submission/<label>/`: the manuscript split the way journals with
#' double-blind review ask for -- a title page, and a main text that opens
#' with the title and names nobody -- or, signed, the main text alone; the
#' supplement as its own document, every
#' figure on its own at 600 dpi, a cover letter -- dated, with the title of
#' the manuscript, signed by the corresponding author, and with the DOI of
#' the data once [deposit_zenodo()] has reserved it -- a checklist of what is
#' left to do by hand, and the data and code compendium, zipped, ready for
#' Zenodo or Dryad. Everything in it is rebuilt on every call except the cover
#' letter, which is never overwritten.
#'
#' It records `renv.lock` first, so the compendium carries the environment this
#' submission came out of -- the version of easypaper that built it included.
#'
#' Double-blind review also needs the sections that identify you off the main
#' text. They move to the title page: by default the Acknowledgements, the
#' CRediT statement, the conflict of interest statement and the data
#' availability statement, which is the list `blinded-sections:` sets in the
#' `easypaper:` block of `_quarto.yml`, in the order they come out on the
#' title page. The page is built from the manuscript and needs no file of its
#' own; a `title_page.qmd` in the project, to add a running head or a word
#' count, is used as the page.
#'
#' The compendium is signed: `data_and_code.zip` is the one deposited, and a
#' deposit names its authors. A double-blind submission also gets
#' `data_and_code_blinded.zip`, for the reviewers: the same compendium with
#' the authors taken out of what the package writes into it -- the creators
#' of the metadata (`creators.csv`, `dataspice.json` and its page), the
#' copyright line of `LICENSE-CODE`, the README -- and out of `renv.lock`,
#' which records the authors of every package it lists and the pages of
#' each, and easypaper itself, which the analysis does not use and which,
#' installed from GitHub, names the account it came from. A name, email,
#' ORCID, affiliation or account of an author still found in it -- in a
#' script, in the data, a package of yours installed from GitHub -- is
#' reported with the file it is in, to take out of the project by hand. An
#' account is the user part of an author's email and the owner of the
#' project's GitHub repository.
#'
#' @param journal The citation style, by the name of its `.csl` without the
#'   extension (see [list_journals()]). `NULL`, the default, takes the one the
#'   manuscript declares in its `csl:` line.
#' @param label Names the folder inside `submission/` and every file in it.
#'   Left alone it is the journal's own name with the spaces taken out:
#'   `"ecology-letters"` gives `submission/EcologyLetters/`. Pass your own for
#'   a second version, or for a trial you want to keep apart.
#' @param caption_style How figures and tables are named: `"default"`,
#'   `"abbrev"`, `"colon"`, `"compact"`, `"nature"`, or one of your own (see
#'   [render_docx()]).
#' @param figure_format The format of the standalone figures: `"tiff"` (what
#'   journals ask for), `"png"` or `"jpg"`.
#' @param blind `TRUE` (the default) splits the manuscript for double-blind
#'   review: a title page with the authors and the sections that identify
#'   them, a main text that names nobody, and a copy of the compendium that
#'   names nobody either. `FALSE` sends one signed main text, with all of it,
#'   and no title page.
#' @param snapshot `TRUE` (the default) records `renv.lock` before building
#'   the compendium. `FALSE` leaves a lockfile you maintain by hand alone.
#' @param suppl_figures `"separate"` (the default) leaves the supplementary
#'   figures and tables in the supplement, and rewrites their citations in the
#'   main text to "Figure S1". `"main"` keeps them at the end of the main text.
#'   Supplementary text (an extended Methods) always goes out on its own, with
#'   its own reference list.
#' @param line_numbers `TRUE` (the default) numbers every line of the main
#'   text and of the title page, continuously, which is what reviewers cite.
#'   `FALSE` leaves them unnumbered.
#' @param line_spacing The line spacing of the main text and of the title
#'   page: `2` (the default, double), `1.5` or `1`.
#' @param suppl_line_spacing The line spacing of the supplement: `1.5` (the
#'   default), `1` or `2`. Its lines are not numbered.
#' @param path The project, or any folder inside it. The working directory by
#'   default, which is the project root once its `.Rproj` is open.
#' @return The path of the submission folder, invisibly.
#' @seealso [make_preprint()] for a preprint server, and [render_docx()] for
#'   the documents alone.
#' @export
#' @examples
#' \dontrun{
#' # Inside a project, with its .Rproj open:
#' make_submission()                               # -> submission/JournalofEcology/
#' make_submission(label = "JournalofEcology_v2")    # a second version, apart
#' make_submission("ecology-letters", figure_format = "png", blind = FALSE)
#' }
make_submission <- function(journal = NULL, label = NULL,
                            caption_style = "default", figure_format = "tiff",
                            blind = TRUE, snapshot = TRUE,
                            suppl_figures = "separate", line_numbers = TRUE,
                            line_spacing = 2, suppl_line_spacing = 1.5,
                            path = ".") {
  .check_flag(blind, "blind")
  .enter_project(path)
  outer <- .batch()
  .check_flag(line_numbers, "line_numbers")
  .check_spacing(line_spacing, "line_spacing")
  .check_spacing(suppl_line_spacing, "suppl_line_spacing")
  figure_format <- match.arg(figure_format, FIG_FORMATS)
  suppl_figures <- match.arg(suppl_figures, c("separate", "main"))
  journal <- .resolve_journal(journal)
  jname <- .journal_name(journal)
  # No label: the journal names the folder and the files. Letters and digits
  # only, because this becomes a path and a file name.
  if (is.null(label) || !nzchar(label)) label <- .label_from(jname)
  root <- .p("submission", label)
  man  <- file.path(root, "manuscript")
  dir.create(man, recursive = TRUE, showWarnings = FALSE)

  .check_quarto(); .check_license(); sync_licenses(quiet = TRUE)
  check_citations(); check_crossrefs(quiet = TRUE)

  # 1) main text, without the supplement. supplement = FALSE: step 3 renders
  #    it, with this label on its file names.
  f <- .render("docx", journal, caption_style, "docx",
               blinded = blind, suppl_figures = suppl_figures,
               supplement = FALSE)
  main_file <- file.path(man, sprintf("main_%s.docx", label))
  file.rename(f, main_file)
  .docx_layout(main_file, line_numbers, line_spacing)

  # 2) title page, with title and authors taken from the manuscript. Only a
  #    double-blind submission has one: signed, the main text already opens
  #    with the title, the authors and their affiliations, and carries the
  #    statements at the end, so a page repeating them would only drift.
  title_file <- file.path(man, sprintf("title_%s.docx", label))
  if (blind) {
    own <- rmarkdown::yaml_front_matter(.master())
    tp  <- .build_title_page(journal)
    on.exit(unlink(c(tp, sub("[.]qmd$", ".docx", tp))), add = TRUE)
    # A loose file, not in the render: list, so how its chunks run has to
    # travel with the call: the affiliations() chunk it is given, and
    # whatever a project works out on it, a word count, would otherwise print
    # its code above the title.
    cfg <- yaml::read_yaml(.p("_quarto.yml"))
    .rendering()
    quarto::quarto_render(tp, output_format = "docx",
                          metadata = c(list(author = .render_author(own),
                                            `reference-doc` = .word_template("manuscript")),
                                       cfg[intersect(c("execute", "knitr"),
                                                     names(cfg))]),
                          as_job = FALSE)
    .repair_docx(sub("[.]qmd$", ".docx", tp))
    # Not in the render: list, so Quarto leaves the output next to the input.
    file.copy(sub("[.]qmd$", ".docx", tp), title_file, overwrite = TRUE)
    .docx_layout(title_file, line_numbers, line_spacing)
  } else if (file.exists(title_file)) {
    # Left by a blinded call into the same folder: it no longer belongs here.
    unlink(title_file)
  }

  # 3) standalone supplement(s). With suppl_figures = "main" the figures and
  #    tables are already at the end of main_*.docx, so only the supplementary
  #    TEXT is rendered on its own.
  all_suppl <- .suppl_files()
  to_render <- if (suppl_figures == "main") {
                 setdiff(all_suppl, .suppl_float_files(all_suppl))
               } else all_suppl
  sup <- render_supplementary(journal, caption_style, files = to_render,
                              blind = blind)
  for (i in seq_along(sup)) {
    nm <- if (length(sup) == 1L) sprintf("supporting_information_%s.docx", label)
          else sprintf("supporting_information_%s_%s.docx",
                       .suppl_name(to_render[i]), label)
    file.copy(sup[i], file.path(man, nm), overwrite = TRUE)
    .docx_layout(file.path(man, nm), line_spacing = suppl_line_spacing)
  }

  # 4) standalone figures and the compendium
  .export_figures(file.path(man, "figures"), figure_format)
  export_code()
  # The lockfile is written HERE, at submission time: this is the output it
  # has to describe. renv::init() is not required -- snapshot reads the
  # project code and records what your library holds.
  if (isTRUE(snapshot)) .record_env()
  # Signed, always: it is the one deposited, and a deposit names its authors.
  # A double-blind submission also gets a copy with no author in it, for the
  # reviewers.
  dc <- file.path(root, "data_and_code")
  .export_data_code(dc, blinded = FALSE)
  zip::zip(file.path(root, "data_and_code.zip"), basename(dc), root = root)
  bc <- file.path(root, "data_and_code_blinded")
  if (blind) {
    .blind_compendium(dc, bc)
    unlink(paste0(bc, ".zip"))
    zip::zip(paste0(bc, ".zip"), basename(bc), root = root)
  } else {
    # Left by a blinded call into the same folder: it no longer belongs here.
    unlink(c(bc, paste0(bc, ".zip")), recursive = TRUE)
  }

  # 5) what is written by hand. The journal's real name, not the label: the
  #    label is a file name and may be anything you passed.
  .write_cover_letter(file.path(root, sprintf("cover_letter_%s.docx", label)),
                      jname)
  .write_checklist(file.path(root, "CHECKLIST.md"), jname, label, blind)
  unlink(.p("output", "figures"), recursive = TRUE)

  message("\nSubmission folder ready: ", root)
  if (outer) .report_length(force = TRUE)
  invisible(root)
}

#' Build a preprint deposit
#'
#' `make_submission()`'s sibling, for the other destination. Writes
#' `submission/<label>/`: the manuscript as ONE signed PDF -- a preprint
#' carries its authors, and is not reviewed blind -- its supplement as PDF
#' too, every figure on its own, and the data and code compendium, zipped.
#' There is no cover letter: there is no editor. Nor is there a short title,
#' even when the manuscript has one: a running head is what a journal asks
#' for, not a preprint server. A `README.md` inside says what
#' goes to the preprint server and what goes to the data repository, and what
#' to do before pressing submit.
#'
#' It needs a LaTeX installation for the PDF: `tinytex::install_tinytex()` is
#' enough.
#'
#' @inheritParams make_submission
#' @param journal The citation style. A preprint has no house style, so this
#'   is only about which convention you prefer to read. `NULL` takes the
#'   manuscript's own.
#' @param label Names the folder inside `submission/` and every file in it.
#'   Defaults to the server you are most likely to post to; change it for
#'   another one, or for a second version.
#' @param snapshot `TRUE` (the default) records `renv.lock` before building
#'   the compendium.
#' @param line_numbers `TRUE` (the default) numbers every line of the
#'   manuscript PDF, continuously, which is what readers and reviewers of a
#'   preprint cite; `FALSE` leaves them unnumbered.
#' @param line_spacing,suppl_line_spacing The line spacing of the manuscript
#'   and of the supplement: `1`, `1.5` or `2`. `NULL`, the default, keeps the
#'   `linestretch` of the pdf format in `_quarto.yml` -- `1.5` in the
#'   template.
#' @return The path of the deposit, invisibly.
#' @seealso [make_submission()].
#' @export
#' @examples
#' \dontrun{
#' # Inside a project, with its .Rproj open:
#' make_preprint()                     # -> submission/bioRxiv/
#' make_preprint(label = "EcoEvoRxiv")
#' }
make_preprint <- function(journal = NULL, label = "bioRxiv",
                          caption_style = "default", figure_format = "tiff",
                          snapshot = TRUE, suppl_figures = "separate",
                          line_numbers = TRUE, line_spacing = NULL,
                          suppl_line_spacing = NULL, path = ".") {
  .enter_project(path)
  outer <- .batch()
  .check_flag(line_numbers, "line_numbers")
  if (!is.null(line_spacing)) .check_spacing(line_spacing, "line_spacing")
  if (!is.null(suppl_line_spacing)) {
    .check_spacing(suppl_line_spacing, "suppl_line_spacing")
  }
  # Both PDFs are rendered through LaTeX, so the layout goes into what
  # Quarto is handed rather than onto the file afterwards.
  .set_layout(main  = list(line_numbers = line_numbers,
                           line_spacing = line_spacing),
              suppl = list(line_spacing = suppl_line_spacing))
  figure_format <- match.arg(figure_format, FIG_FORMATS)
  suppl_figures <- match.arg(suppl_figures, c("separate", "main"))
  journal <- .resolve_journal(journal)
  if (is.null(label) || !nzchar(label)) label <- "bioRxiv"
  root <- .p("submission", label)
  man  <- file.path(root, "manuscript")
  dir.create(man, recursive = TRUE, showWarnings = FALSE)

  .check_quarto(); .check_license(); sync_licenses(quiet = TRUE)
  check_citations(); check_crossrefs(quiet = TRUE)

  # 1) the manuscript, as one signed PDF. blinded = FALSE keeps the title
  #    block, which is the whole difference from a submission. No short
  #    title: a running head is what a journal asks for, not a server.
  f <- .render("pdf", journal, caption_style, "pdf",
               blinded = FALSE, suppl_figures = suppl_figures,
               supplement = FALSE, short_title = FALSE)
  file.rename(f, file.path(man, sprintf("preprint_%s.pdf", label)))

  # 2) the supplement(s), also as PDF: a server takes one file per document.
  all_suppl <- .suppl_files()
  to_render <- if (suppl_figures == "main") {
                 setdiff(all_suppl, .suppl_float_files(all_suppl))
               } else all_suppl
  # A preprint is signed, so its supplement carries the authors too.
  sup <- render_supplementary(journal, caption_style, output_format = "pdf",
                              files = to_render, blind = FALSE)
  for (i in seq_along(sup)) {
    nm <- if (length(sup) == 1L) sprintf("supporting_information_%s.pdf", label)
          else sprintf("supporting_information_%s_%s.pdf",
                       .suppl_name(to_render[i]), label)
    file.copy(sup[i], file.path(man, nm), overwrite = TRUE)
  }

  # 3) figures on their own, the code, and the environment they ran in
  .export_figures(file.path(man, "figures"), figure_format)
  export_code()
  if (isTRUE(snapshot)) .record_env()

  # 4) the compendium, never blinded: a preprint deposit is signed
  dc <- file.path(root, "data_and_code")
  .export_data_code(dc, blinded = FALSE)
  zip::zip(file.path(root, "data_and_code.zip"), basename(dc), root = root)

  # 5) what is left to do by hand
  .write_preprint_readme(file.path(root, "README.md"), label)
  unlink(.p("output", "figures"), recursive = TRUE)

  message("\nPreprint deposit ready: ", root)
  if (outer) .report_length(force = TRUE)
  invisible(root)
}

# --- Includes ----------------------------------------------------------------------

#' Resolve the {{< include >}} lines and return the full text of a document.
#' @noRd
.expand_includes <- function(f) {
  .expand_includes_text(readLines(f, warn = FALSE))
}

#' Same as .expand_includes() but starting from a character vector.
#' @noRd
.expand_includes_text <- function(l) {
  out <- character(0)
  for (x in l) {
    m <- regmatches(x, regexec("\\{\\{< *include +([^ >]+) *>\\}\\}", x))[[1]]
    out <- c(out, if (length(m) == 2) .expand_includes(.p(m[2])) else x)
  }
  out
}

# --- The supplement ------------------------------------------------------------------

#' A supplementary file of _sections/: numbered, with `suppl` as a word of
#' its name -- 12.1_suppl_material.qmd in the template, numbered .1 from the
#' start so a second one, 12.2_suppl_methods.qmd, goes beside it without
#' renaming anything, the way Results is 04.1 and 04.2. By name, not by
#' number, so a project numbered its own way -- 8_suppl_material.qmd -- is
#' read too. "03_supplied.qmd" is not one.
#' @noRd
SUPPL_FILE <- "^[0-9][0-9.]*_(.*_)?suppl(ement[a-z]*)?[_.].*qmd$"

#' The supplementary content files, in order.
#' @noRd
.suppl_files <- function() {
  f <- list.files(.p("_sections"), SUPPL_FILE, full.names = TRUE)
  f[.section_order(basename(f))]
}

#' The order of the section files: by the numbers in front, read as numbers
#' -- 2 before 10, whether or not it was written 02, and 12 before 12.1 --
#' then by name. Files with no number go last.
#' @noRd
.section_order <- function(f) {
  key <- vapply(f, function(x) {
    num <- sub("[.]+$", "", regmatches(x, regexpr("^[0-9][0-9.]*", x)))
    if (!length(num) || !nzchar(num)) return(paste0("~", x))
    parts <- as.integer(strsplit(num, ".", fixed = TRUE)[[1]])
    paste0(paste(sprintf("%06d", parts), collapse = "."), " ", x)
  }, character(1), USE.NAMES = FALSE)
  # By bytes: a locale's collation would ignore the space and the dots.
  order(key, method = "radix")
}

#' The lines of `l` that include a supplementary file of _sections/.
#' @noRd
.suppl_include_lines <- function(l) {
  inc <- grepl("\\{\\{< *include +_sections/", l)
  f <- sub("^.*\\{\\{< *include +_sections/([^ >]+).*$", "\\1", l)
  which(inc & grepl(SUPPL_FILE, f))
}

#' The file of the main figures: numbered, and called `figures` --
#' 10_figures.qmd, or 6_figures.qmd in a project numbered its own way. NULL
#' when the project has none.
#' @noRd
.figures_file <- function() {
  f <- list.files(.p("_sections"), "^[0-9][0-9.]*_figures[.]qmd$",
                  full.names = TRUE)
  if (length(f)) f[.section_order(basename(f))][1]
}

#' The two ways Quarto lets you label a supplementary float: wrapped in a div
#' (`{#sfig-x}`) or as a chunk option (`#| label: sfig-x`). Both are read, and
#' from ONE place. This pattern drifting apart from .crossref_labels() -- which
#' always read both -- is how a citation could survive unreplaced and reach a
#' submitted .docx as "?@sfig-x", with check_crossrefs() seeing nothing wrong
#' because the label did exist.
#' @noRd
SUPPL_LABEL <- "(?:\\{#|#\\|\\s*label:\\s*)(sfig|stbl)-[A-Za-z0-9_:.-]+"

#' The float ids of one supplementary file, in order of appearance.
#' @noRd
.suppl_label_ids <- function(f) {
  txt <- readLines(f, warn = FALSE)
  ids <- unlist(regmatches(txt, gregexpr(SUPPL_LABEL, txt, perl = TRUE)))
  ids <- sub("^(?:\\{#|#\\|\\s*label:\\s*)", "", ids, perl = TRUE)
  ids[!duplicated(ids)]   # a div and its chunk may carry the same id
}

#' Whether a supplementary file carries figures or tables. Nothing to
#' declare: a file is a "floats" file if it defines an sfig or stbl label. The
#' rest are supplementary TEXT (an extended Methods), which is what you want
#' in its own document so that it carries its own reference list.
#' @noRd
.suppl_is_floats <- function(f) {
  length(.suppl_label_ids(f)) > 0L
}

#' @noRd
.suppl_float_files <- function(files = .suppl_files()) {
  files[vapply(files, .suppl_is_floats, logical(1))]
}

#' Short name of a supplementary file, used in the output file name.
#' "12.2_suppl_methods.qmd" -> "methods"
#' @noRd
.suppl_name <- function(f) {
  n <- tools::file_path_sans_ext(basename(f))
  n <- sub("^[0-9][0-9.]*_", "", n)
  n <- sub("^suppl(ementary)?_?", "", n)
  if (nzchar(n)) n else "material"
}

#' crossref block for the k-th file that carries floats, out of n such files.
#'
#' With a single one, numbering is flat: Figure S1, Figure S2. Only when the
#' figures are SPREAD over several documents does the prefix have to carry the
#' appendix -- Figure S1.1, Figure S2.1 -- because Quarto restarts its counter
#' in every document it renders, and two bare "Figure S1" would name two
#' different figures.
#' @noRd
.suppl_crossref <- function(k, n, caption_style = "default") {
  cr <- crossref_metadata(caption_style)
  if (n <= 1L) return(cr)
  for (i in seq_along(cr$custom)) {
    key <- cr$custom[[i]]$key
    if (!is.null(key) && key %in% c("sfig", "stbl")) {
      cr$custom[[i]][["reference-prefix"]] <-
        paste0(cr$custom[[i]][["reference-prefix"]], k, ".")
    }
  }
  cr
}

#' Label of every supplementary figure and table, exactly as the reader sees
#' it. This is what replaces @sfig-x in the main text when the floats are NOT
#' in that document.
#' @noRd
.suppl_numbering <- function(caption_style = "default") {
  files <- .suppl_float_files()
  out <- character(0)
  for (k in seq_along(files)) {
    pref <- list(sfig = "Figure S", stbl = "Table S")
    for (kind in .suppl_crossref(k, length(files), caption_style)$custom) {
      if (!is.null(kind$key)) pref[[kind$key]] <- kind[["reference-prefix"]]
    }
    ids <- .suppl_label_ids(files[k])
    n <- list(sfig = 0L, stbl = 0L)
    for (id in ids) {
      kind <- sub("-.*$", "", id)
      n[[kind]] <- n[[kind]] + 1L
      out[id] <- paste0(pref[[kind]], n[[kind]])
    }
  }
  out
}

#' The yaml package writes logicals as yes/no (YAML 1.1) and Quarto reads YAML
#' 1.2, which only accepts true/false.
#' @noRd
.as_yaml <- function(x) {
  as_bool <- function(v) structure(ifelse(v, "true", "false"), class = "verbatim")
  trimws(yaml::as.yaml(x, handlers = list(logical = as_bool)), which = "right")
}

#' A format block for a generated wrapper: the project's settings for that
#' format, and for Word the template the document is written on. Never an
#' empty block -- Quarto refuses `docx:` with nothing under it -- but
#' `default` when there is nothing to set.
#' @noRd
.format_block <- function(own, fmt, template = "manuscript") {
  b <- if (is.list(own)) own else list()
  if (identical(fmt, "docx")) b[["reference-doc"]] <- .word_template(template)
  if (length(b)) b else "default"
}

#' A pdf format block with the layout a deliverable asked for: the line
#' spacing as `linestretch`, and the line numbers through LaTeX's lineno,
#' added to whatever the project already puts in the header. NULL leaves
#' either as _quarto.yml has it.
#' @noRd
.pdf_layout <- function(b, layout) {
  if (is.null(layout)) return(b)
  if (!is.list(b)) b <- list()
  if (!is.null(layout$line_spacing)) b$linestretch <- layout$line_spacing
  if (isTRUE(layout$line_numbers)) {
    inc <- b[["include-in-header"]]
    if (is.list(inc) && !is.null(names(inc))) inc <- list(inc)
    b[["include-in-header"]] <- c(as.list(inc),
                                  list(list(text = "\\usepackage{lineno}\n\\linenumbers")))
  }
  b
}

#' Wrapper for one supplementary file: supplementary.qmd with its include
#' swapped and, when there are several, its title turned into "Appendix Sk".
#' @noRd
.build_supplementary <- function(section, k, n = 1L, fmt = "docx",
                                 blinded = FALSE, caption_style = "default") {
  f <- .p("supplementary.qmd")
  l <- if (file.exists(f)) readLines(f, warn = FALSE) else character(0)
  include <- sprintf("{{< include _sections/%s >}}", basename(section))
  b   <- .yaml_bounds(l)
  end <- if (is.null(b)) 0L else b[2]
  yml <- if (end > 2L) {
    yaml::read_yaml(text = paste(l[2:(end - 1L)], collapse = "\n"))
  }
  if (is.null(yml)) yml <- list()
  if (is.null(yml$title)) yml$title <- "Supporting Information"
  body <- if (end) l[-seq_len(end)] else l

  # The setup and the section go in here, so neither is written twice: the
  # setup is the manuscript's, and the section is included there.
  body <- c("", "```{r setup-suppl}", "#| include: false", "#| purl: false",
            'source(here::here("R/setup.R"))', "```", "", include, "", body)

  # With a single supplementary document its own title stands ("Supporting
  # Information"); with several, each one is named after its appendix.
  if (n > 1L) yml$title <- sprintf("Appendix S%d", k)

  # The wrapper is not in the render: list of _quarto.yml, so Quarto reads it
  # as a loose file and NOTHING in the project configuration reaches it.
  # Whatever the supplement needs from there is copied in here, by hand.
  proj <- yaml::read_yaml(.p("_quarto.yml"))

  # The project's own settings for the format asked for, so the supplement
  # comes out of the same press as the paper. Without them a .pdf falls back
  # on Quarto's defaults -- KOMA-Script and lualatex -- and dies on a lean
  # LaTeX install with "scrartcl.cls not found". Whatever supplementary.qmd
  # sets for itself wins; the Word template is the supplement's own.
  own <- if (is.list(yml$format)) yml$format[[fmt]] else NULL
  base <- proj$format[[fmt]]
  if (is.list(base) && is.list(own)) own <- utils::modifyList(base, own)
  if (!is.list(own)) own <- base
  yml$format <- list()
  yml$format[[fmt]] <- .format_block(own, fmt, template = "supplement")
  if (identical(fmt, "pdf")) {
    yml$format$pdf <- .pdf_layout(yml$format$pdf, .ep$layout$suppl)
    yml$format$pdf <- .pdf_captions(yml$format$pdf,
                                    crossref_metadata(caption_style))
  }

  # How the chunks are run is the other half of that press. Outside a project
  # `echo` defaults to true, so the supplement came out with the R code of
  # every chunk printed above its own figure; its figures came out at 96 dpi
  # instead of 600, written where figures/png/ never saw them. Both blocks are
  # merged key by key, and anything supplementary.qmd sets for itself wins.
  for (nm in c("execute", "knitr")) {
    if (is.null(proj[[nm]])) next
    mine <- if (is.null(yml[[nm]])) list() else yml[[nm]]
    yml[[nm]] <- utils::modifyList(proj[[nm]], mine)
  }

  dest <- .p(sprintf("tmp_supplementary_S%d.qmd", k))
  writeLines(c("---", .as_yaml(yml), "---", body), dest)
  dest
}

# --- The main text -------------------------------------------------------------------

#' A journal's name as a file name: letters and digits, nothing else.
#' "Ecology Letters" -> "EcologyLetters".
#' @noRd
.label_from <- function(x) {
  s <- gsub("[^A-Za-z0-9]", "", x)
  if (nzchar(s)) s else "submission"
}

#' The sections a double-blind submission keeps off the main text.
#'
#' They travel on the title page instead. Their headings are the ones
#' manuscript.qmd uses, and their text is written there, once: nothing is
#' duplicated, it is moved. A project draws the line somewhere else with
#' `blinded-sections:` in the easypaper: block of _quarto.yml: the title page
#' takes them from there, in that order.
#' @noRd
BLINDED_SECTIONS <- c("Acknowledgements",
                      "CRediT authorship contribution statement",
                      "Conflict of Interest Statement",
                      "Data availability statement")

#' @noRd
.blinded_sections <- function() {
  as.character(unlist(.config("blinded-sections", BLINDED_SECTIONS)))
}

#' One top-level section: its heading and everything down to the next one.
#' character(0) when that heading is not there.
#' @noRd
.section_block <- function(l, heading) {
  i <- which(trimws(l) == paste("#", heading))
  if (!length(i)) return(character(0))
  i <- i[1]
  j <- i + 1L
  while (j <= length(l) && !grepl("^# ", l[j])) j <- j + 1L
  # The blank lines before the next heading belong to neither section.
  while (j - 1L > i && !nzchar(trimws(l[j - 1L]))) j <- j - 1L
  l[seq.int(i, j - 1L)]
}

#' Those sections, gone, and the blank lines they left behind with them.
#' Recomputed each time, because every removal shifts the lines under it.
#' @noRd
.drop_sections <- function(l, headings) {
  for (h in headings) {
    n <- length(.section_block(l, h))
    if (!n) next
    i <- which(trimws(l) == paste("#", h))[1]
    j <- i + n
    while (j <= length(l) && !nzchar(trimws(l[j]))) j <- j + 1L
    l <- l[-seq.int(i, j - 1L)]
    # One blank line stays where the section was, so whatever followed it
    # still begins a block of its own.
    if (i > 1L && i <= length(l) && nzchar(trimws(l[i - 1L]))) {
      l <- append(l, "", after = i - 1L)
    }
  }
  l
}

#' The mark of a title_page.qmd that says where the affiliations go.
#' @noRd
AFFILIATIONS_SLOT <- "^\\s*<!--\\s*affiliations\\s*-->\\s*$"

#' Where manuscript.qmd keeps its affiliations: the lines of the chunks that
#' call affiliations() -- the chunk of the template, or one a project wrote
#' its own way. A double-blind main text drops them and the title page is
#' given them. None is a paper without affiliations.
#' @noRd
.affiliation_lines <- function(txt) {
  fence  <- grepl("^\\s*```", txt)
  inside <- (cumsum(fence) %% 2 == 1) & !fence
  calls  <- which(inside & grepl("(^|[^[:alnum:]_.])affiliations\\(", txt) &
                    !grepl("^\\s*#", txt))
  f <- which(fence)
  chunks <- unlist(lapply(calls, function(i) {
    # A chunk left open runs to the end of the file, the way knitr reads it.
    end <- f[f > i]
    seq.int(max(f[f < i]), if (length(end)) min(end) else length(txt))
  }))
  # Or inline, `r easypaper::affiliations()`, on a line of its own.
  inline <- which(!inside & !fence &
                    grepl("`r [^`]*affiliations\\(", txt))
  sort(unique(c(chunks, inline)))
}

#' Self-contained document holding the main text WITHOUT the supplement.
#'
#' @param blinded TRUE removes what identifies you -- the authors, the
#'   affiliations and the correspondence line, and the sections listed in
#'   .blinded_sections(), which move to the title page -- and keeps the
#'   title, which opens the main text.
#'
#' This is done here and not with a Lua filter because Quarto resolves
#' cross-references after user filters: once the target is cut, the @sfig-x
#' citations would be left as "?@sfig-x" in the .docx that goes to the
#' journal. Verified. Here they are replaced by their text ("Figure S1")
#' before compiling.
#'
#' @param short_title FALSE leaves the short title out: make_preprint()
#'   prints none, a running head being the business of a journal.
#' @param whole TRUE keeps the supplement in: the manuscript whole, for the
#'   .html and for a project with no supplementary section. It still goes
#'   through a copy, because the document's own front matter wins over the
#'   metadata passed to quarto_render(), and the title block a render hands
#'   Quarto -- the authors on one line, no affiliations of Quarto's own -- has
#'   to be written into the front matter itself.
#' @noRd
.build_main_text <- function(journal, caption_style, fmt = "docx",
                             blinded = FALSE, suppl_figures = "separate",
                             whole = FALSE, short_title = TRUE) {
  suppl_figures <- match.arg(suppl_figures, c("separate", "main"))
  txt <- readLines(.master(), warn = FALSE)

  # Blinded: drop the affiliations and the correspondence line from the body.
  # Title, authors and date come from the YAML, further down.
  if (blinded) {
    a <- .affiliation_lines(txt)
    if (length(a)) txt <- txt[-a]
    # Not deleted: .build_title_page() puts them on the title page.
    moved <- .cited_in_sections(txt, .blinded_sections())
    txt <- .drop_sections(txt, .blinded_sections())
  }

  # 1) decide what supplementary content stays in this document.
  #    suppl_figures = "main"     -> the figures and tables stay at the end,
  #                                  and Quarto numbers them Figure S1 itself
  #    suppl_figures = "separate" -> nothing stays; the citations to them are
  #                                  replaced by their text further down
  #    Supplementary TEXT always leaves: its whole point is a document with
  #    its own reference list.
  files  <- .suppl_files()
  floats <- .suppl_float_files(files)
  keep   <- if (suppl_figures == "main") floats else character(0)
  cut    <- if (whole) character(0) else setdiff(files, keep)

  drop <- unlist(lapply(basename(cut), function(f) grep(f, txt, fixed = TRUE)))
  if (!whole && !length(keep)) {
    # Nothing supplementary stays: the section header goes too, together with
    # the blank lines and the pagebreak before it.
    i <- grep("^#\\s+Supporting information\\s*$", txt)
    if (length(i) != 1) {
      stop("Cannot find exactly one '# Supporting information' header in ",
           "manuscript.qmd.", call. = FALSE)
    }
    drop <- unique(c(i, drop))
    k <- i - 1L
    while (k >= 1 && (!nzchar(trimws(txt[k])) || grepl("pagebreak", txt[k]))) {
      drop <- c(drop, k); k <- k - 1L
    }
  }
  if (length(drop)) txt <- txt[-drop]

  # 2) resolve the includes and replace the citations to the supplement
  body <- .expand_includes_text(txt)
  if (!whole && !length(keep) && length(.suppl_include_lines(body))) {
    stop("The main text still includes a supplementary file. Check the ",
         "'# Supporting information' section of manuscript.qmd.", call. = FALSE)
  }
  # Only what LEFT the document needs its citations rewritten. Twice: here, on
  # the source, for every citation written in it; and again after knitr has
  # run, for the ones only code writes -- a function in R/setup.R that returns
  # "see @stbl-raw" -- which would otherwise reach the .docx as "?@stbl-raw".
  numbers <- if (whole || length(keep)) character(0)
             else .suppl_numbering(caption_style)
  body <- .resolve_suppl_refs(body, numbers)

  # 3) self-contained YAML header: the temporary file is not in the render:
  #    list of _quarto.yml, so it does not inherit the project configuration.
  yml <- yaml::read_yaml(.p("_quarto.yml"))
  yml$project <- NULL
  yml$easypaper <- NULL
  yml$crossref <- crossref_metadata(caption_style)
  fmts <- yml$format
  yml$format <- list()
  yml$format[[fmt]] <- .format_block(fmts[[fmt]], fmt, template = "manuscript")
  if (identical(fmt, "pdf")) {
    # The main text is numbered, as the Word template numbers the .docx; a
    # deliverable that asks otherwise -- make_preprint(line_numbers = FALSE)
    # -- says so through .set_layout(). The supplement is not numbered.
    layout <- .ep$layout$main
    if (is.null(layout$line_numbers)) layout$line_numbers <- TRUE
    yml$format$pdf <- .pdf_layout(yml$format$pdf, layout)
    yml$format$pdf <- .pdf_captions(yml$format$pdf, yml$crossref)
  }
  own <- rmarkdown::yaml_front_matter(.master())
  for (nm in names(own)) yml[[nm]] <- own[[nm]]
  yml <- if (short_title) .with_short_title(yml, own)
         else .with_short_title(yml, list())
  # On one line, the way a paper prints them: handed the list, Quarto would
  # give each author a paragraph of its own. The affiliations are written by
  # the affiliations() chunk under it; Quarto's own would print them twice.
  yml$author <- .render_author(own)
  yml$affiliations <- NULL
  # After the manuscript's own YAML, never before: the manuscript declares a
  # `csl:` of its own and copying it over would undo the journal this call
  # resolved -- the one you named, if you named one.
  yml$csl <- .csl_path(journal)
  # The references from the copy with the scientific names in italics.
  yml$bibliography <- .bibliography()
  if (blinded) {
    # The title stays at the head of the main text: a journal expects it on
    # the anonymised manuscript and it names nobody. What goes is the author
    # block, and the date with it.
    for (nm in c("author", "affiliations", "date", "date-format")) {
      yml[[nm]] <- NULL
    }
    # What only the sections moved to the title page cite stays in the
    # reference list: it is the paper's one list, and the title page has none.
    yml$nocite <- .nocite(yml$nocite, moved)
  }

  end <- grep("^---\\s*$", body)[2]
  dest <- .p("tmp_main_text.qmd")
  writeLines(c("---", .as_yaml(yml), "---", "",
               if (length(numbers)) .suppl_refs_chunk(numbers),
               body[(end + 1):length(body)]), dest)
  dest
}

#' The references cited in some sections of the manuscript: their keys, with
#' the cross-references left out. `txt` is manuscript.qmd, with its includes
#' still to expand.
#' @noRd
.cited_in_sections <- function(txt, headings) {
  blk <- unlist(lapply(headings, function(h) .section_block(txt, h)))
  if (!length(blk)) return(character(0))
  k <- .at_keys_text(.expand_includes_text(blk))
  unique(k[!.is_crossref(k)])
}

#' A `nocite:` with these keys added to whatever it already lists.
#' @noRd
.nocite <- function(nocite, keys) {
  if (!length(keys)) return(nocite)
  paste(c(nocite, paste0("@", keys)), collapse = ", ")
}

#' Rewrite the citations to supplementary floats that left the document.
#'
#' `[@sfig-x]` becomes (Figure S1) and `@sfig-x` becomes Figure S1, with the
#' numbers .suppl_numbering() gives -- the same ones the supplement prints.
#' Longest ids first: with @sfig-map and @sfig-map-detail both defined, the
#' short one must not eat the start of the long one. The trailing lookaheads
#' stop a match halfway through a longer id while still allowing the
#' sentence-final "@stbl-raw.": a dot only belongs to the id when a letter or a
#' digit follows it. The leading lookbehind is pandoc's rule for what is a
#' citation at all, the same as .at_keys().
#'
#' Self-contained on purpose -- base R only -- because .suppl_refs_chunk()
#' copies it into the document, where it runs inside the knitr session.
#' @noRd
.resolve_suppl_refs <- function(x, numbers) {
  for (id in names(numbers)[order(-nchar(names(numbers)))]) {
    rx  <- gsub(".", "\\.", id, fixed = TRUE)
    lbl <- gsub("\\", "\\\\", numbers[[id]], fixed = TRUE)
    x <- gsub(paste0("\\[@", rx, "\\]"), paste0("(", lbl, ")"), x, perl = TRUE)
    x <- gsub(paste0("(?<![\\p{L}\\p{N}_\\\\])@", rx,
                     "(?![A-Za-z0-9_:-])(?!\\.[A-Za-z0-9_])"), lbl, x, perl = TRUE)
  }
  x
}

#' The chunk that resolves them after knitr has run.
#'
#' A knitr `document` hook sees the whole markdown knitr produced, after every
#' chunk and every inline `r` has written its text, and before pandoc and
#' Quarto's cross-referencing ever see it. So a citation is rewritten here
#' wherever it came from. The hook it finds is kept and called after this
#' one, so nothing Quarto or rmarkdown set is lost. Never cached: a cached
#' chunk is not run, and the hook would not be set.
#' @noRd
.suppl_refs_chunk <- function(numbers) {
  c("```{r}",
    "#| label: easypaper-suppl-refs",
    "#| include: false",
    "#| cache: false",
    "#| purl: false",
    "# Written by easypaper: supplementary citations in text generated by R code.",
    "local({",
    paste0("  numbers <- ", paste(deparse(numbers), collapse = "\n    ")),
    paste0("  resolve <- ", paste(deparse(.resolve_suppl_refs), collapse = "\n  ")),
    "  prev <- knitr::knit_hooks$get(\"document\")",
    "  if (!is.function(prev)) prev <- identity",
    "  knitr::knit_hooks$set(document = function(x) prev(resolve(x, numbers)))",
    "})",
    "```",
    "")
}

# --- The title page ------------------------------------------------------------------

#' The title page of a double-blind submission, built from the manuscript.
#'
#' Everything on it is written once, in manuscript.qmd and _sections/: the
#' title, the affiliations, and the sections a blinded main text leaves out
#' (.blinded_sections()), each under its heading, in that order. The project
#' needs no file for it. One that has a title_page.qmd -- to add a running
#' head or a word count -- has it used as the page: the
#' affiliations go where it marks them, or under the title; each section
#' under its heading there, or at the end if it has none.
#'
#' The title goes into the copy's front matter, because in Quarto the
#' document's own front matter wins over the metadata passed to
#' quarto_render(). The copy also drops any Word template the page names, so
#' the one quarto_render() is handed -- the package's, or the project's own in
#' format/ -- is the one used.
#'
#' The sections it takes cite like the rest of the paper -- "We thank the
#' authors of @Condit2002" -- so the page gets the journal's style and the
#' bibliography, which a loose file does not inherit from _quarto.yml, and
#' its citations come out as the journal prints them. It has no reference
#' list: the main text has the one list of the paper, and keeps in it what
#' only these sections cite (see .build_main_text()).
#' @noRd
.build_title_page <- function(journal = NULL) {
  own    <- rmarkdown::yaml_front_matter(.master())
  master <- readLines(.master(), warn = FALSE)
  f <- .p("title_page.qmd")
  l <- if (file.exists(f)) readLines(f, warn = FALSE) else character(0)
  b   <- .yaml_bounds(l)
  end <- if (is.null(b)) 0L else b[2]
  yml <- if (end > 2L) {
    yaml::read_yaml(text = paste(l[2:(end - 1L)], collapse = "\n"))
  }
  if (is.null(yml)) yml <- list()
  if (!is.null(own$title)) yml$title <- own$title
  yml <- .with_short_title(yml, own)
  yml$csl <- .csl_path(.resolve_journal(journal))
  yml$bibliography <- .bibliography()
  yml[["suppress-bibliography"]] <- TRUE
  if (is.list(yml$format) && is.list(yml$format$docx)) {
    yml$format$docx[["reference-doc"]] <- NULL
    if (!length(yml$format$docx)) yml$format$docx <- "default"
  }
  body <- if (end) l[-seq_len(end)] else l

  # The affiliations: where the page marks their place, or right under the
  # title. A chunk of the page's own goes: the manuscript's is the one that
  # counts.
  aff  <- master[.affiliation_lines(master)]
  slot <- sort(unique(c(grep(AFFILIATIONS_SLOT, body),
                        .affiliation_lines(body))))
  at   <- if (length(slot)) min(slot) - 1L else 0L
  if (length(slot)) body <- body[-slot]
  body <- append(body, c("", aff, ""), after = at)

  # The sections the main text has just lost, with the text written in the
  # manuscript: under the page's heading when it has one, else at the end.
  for (h in .blinded_sections()) {
    blk <- .section_block(master, h)
    if (!length(blk)) next
    k <- which(trimws(body) == paste("#", h))
    body <- if (length(k)) append(body[-k[1]], blk, after = k[1] - 1L)
            else c(body, "", blk)
  }
  dest <- .p("tmp_title_page.qmd")
  writeLines(c("---", .as_yaml(yml), "---", body), dest)
  dest
}

# --- Figures and compendium -------------------------------------------------------------

#' Standalone figures, renumbered and in the format the journal asks for.
#' The order is the order of appearance in _sections/10_figures.qmd, which is
#' the same one Quarto uses to number them.
#' @noRd
.export_figures <- function(dest, format = "tiff") {
  f <- .figures_file()
  if (is.null(f)) return(invisible(character(0)))
  txt <- readLines(f, warn = FALSE)
  labs <- regmatches(txt, regexpr("(?<=^#\\| label: )fig-[A-Za-z0-9_:.-]+",
                                  txt, perl = TRUE))
  if (!length(labs)) return(invisible(character(0)))
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)

  written <- character(0)
  for (i in seq_along(labs)) {
    src <- .p("figures", format, paste0(labs[i], "-1.", format))
    if (!file.exists(src)) {
      warning("Missing figure ", basename(src),
              ": render the manuscript first.", call. = FALSE)
      next
    }
    # Already converted by export_figure_formats(): all that happens here is
    # the renumbering to the order the reader sees.
    out <- file.path(dest, sprintf("Figure_%d.%s", i, format))
    file.copy(src, out, overwrite = TRUE)
    written <- c(written, out)
  }
  message("Figures exported: ", length(written), " -> ", basename(dest), "/")
  invisible(written)
}

#' Data and code compendium, ready for Zenodo/Dryad.
#' @noRd
.export_data_code <- function(dest, blinded = TRUE) {
  unlink(dest, recursive = TRUE)
  dir.create(file.path(dest, "data"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(dest, "scripts"), showWarnings = FALSE)

  # data/ travels whole, minus its subfolders: metadata/ goes out on its own,
  # below. Whatever the project reads is what the deposit carries -- that is
  # the point of there being one folder.
  if (dir.exists(.p("data"))) {
    files <- list.files(.p("data"), full.names = TRUE)
    files <- files[!dir.exists(files)]
    if (length(files)) file.copy(files, file.path(dest, "data"))
  }
  non_open <- list.files(file.path(dest, "data"), recursive = TRUE,
                         pattern = "[.](xlsx|xls|sav|dta|mdb|accdb)$",
                         ignore.case = TRUE, full.names = TRUE)
  if (length(non_open)) {
    unlink(non_open)
    message("Removed from the compendium (non-open format): ",
            paste(basename(non_open), collapse = ", "))
  }
  if (dir.exists(.p("data/metadata"))) {
    file.copy(.p("data/metadata"), dest, recursive = TRUE)
  }
  # Only the statistical analysis and the setup it needs. A whitelist on
  # purpose: anything else in R/ stays out by default instead of leaking into
  # the deposit. To publish an extra analysis script, name it R/analysis_*.R.
  scripts <- c(.p("R/setup.R"),
               list.files(.p("R"), "^analysis.*[.]R$", full.names = TRUE))
  scripts <- scripts[file.exists(scripts)]
  file.copy(scripts, file.path(dest, "scripts"), overwrite = TRUE)
  for (f in c("output/analysis_code.R", "output/sessionInfo.txt")) {
    if (file.exists(.p(f))) {
      file.copy(.p(f), file.path(dest, "scripts"), overwrite = TRUE)
    }
  }
  # The project README documents the paper, not the deposit: the compendium
  # gets its own, written from what the folder actually holds.
  for (f in c("LICENSE", "LICENSE-CODE", "renv.lock",
              list.files(.p(), "\\.Rproj$"))) {
    if (file.exists(.p(f))) file.copy(.p(f), dest, overwrite = TRUE)
  }
  check_renv(quiet = TRUE)   # warns if it is missing or out of sync

  .write_data_readme(dest, blinded = blinded)

  # No .Rproj.user, .Rhistory or .DS_Store in what gets published.
  junk <- list.files(dest,
                     pattern = "^([.]Rhistory|[.]DS_Store|[.]gitkeep|[.]Rproj[.]user)$",
                     recursive = TRUE, all.files = TRUE, full.names = TRUE,
                     include.dirs = TRUE)
  unlink(junk, recursive = TRUE)
  invisible(dest)
}

#' The compendium for the reviewers of a double-blind submission: the signed
#' one, copied, with the authors taken out of what the package writes into it
#' -- the people of the metadata, the copyright line of the code, the README.
#' What the package did not write, a comment in a script or a column of the
#' data, it cannot rewrite without the risk of breaking it: it says where the
#' authors are still named instead.
#' @noRd
.blind_compendium <- function(src, dest) {
  unlink(dest, recursive = TRUE)
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  file.copy(list.files(src, full.names = TRUE, all.files = TRUE, no.. = TRUE),
            dest, recursive = TRUE)
  md <- file.path(dest, "metadata")

  # creators.csv: as many creators as there are, none of them named, with no
  # affiliation, email or ORCID.
  f <- file.path(md, "creators.csv")
  if (file.exists(f)) {
    cr <- .read_meta(f, colClasses = "character")
    if (nrow(cr)) {
      cr[] <- ""
      if ("name" %in% names(cr)) cr$name <- "Anonymous"
    }
    utils::write.csv(cr, f, row.names = FALSE, na = "")
  }

  # dataspice.json, which write_spice() built from creators.csv, and the page
  # built from it.
  json <- file.path(md, "dataspice.json")
  if (file.exists(json)) {
    j <- jsonlite::read_json(json)
    if (!is.null(j$creator)) {
      n <- if (is.null(names(j$creator))) length(j$creator) else 1L
      j$creator <- rep(list(list(`@type` = "Person", name = "Anonymous")), n)
    }
    jsonlite::write_json(j, json, auto_unbox = TRUE, pretty = TRUE,
                         null = "null")
    for (html in list.files(md, "^index.*[.]html$", full.names = TRUE)) {
      ok <- tryCatch({
        suppressMessages(.spice_page(json, html))
        TRUE
      }, error = function(e) FALSE)
      # A page that could not be rebuilt would still name them: it goes.
      if (!ok) unlink(html)
    }
  }

  # LICENSE-CODE: the copyright line names the holders.
  f <- file.path(dest, "LICENSE-CODE")
  if (file.exists(f)) {
    l <- readLines(f, warn = FALSE)
    l <- sub("^(Copyright \\(c\\) [0-9]{4}) .*$", "\\1 The authors", l)
    writeLines(l, f)
  }

  # renv.lock: renv records the DESCRIPTION of every package, and with it the
  # people who wrote it -- knitr's contributors include a Smith, which is
  # enough to report a John Smith as still named -- and the pages of each,
  # which name the GitHub account it lives in. Restoring reads neither.
  f <- file.path(dest, "renv.lock")
  if (file.exists(f)) .lock_without_people(f)

  .write_data_readme(dest, blinded = TRUE)

  left <- .names_left(dest, .identifiers())
  if (length(left)) {
    warning("The blinded compendium still names the authors:\n",
            paste0("  ", names(left), ": ",
                   vapply(left, paste, "", collapse = ", "), collapse = "\n"),
            "\nTake them out of the project -- a comment in a script, which ",
            "the README also quotes, a column of the data -- and run ",
            "make_submission() again.",
            if ("renv.lock" %in% names(left)) paste0(
              "\nIn renv.lock it is a package installed from an author's ",
              "GitHub account, which renv needs to restore it: install it ",
              "from CRAN if it is there, or take its record out of ",
              "data_and_code_blinded/renv.lock by hand before zipping it ",
              "again."),
            call. = FALSE)
  }
  invisible(dest)
}

#' A renv.lock with the authors and maintainers of its packages taken out --
#' `Author`, `Authors@R`, `Maintainer` -- and their pages, `URL` and
#' `BugReports`, which name the GitHub account a package lives in; and
#' everything renv::restore() reads left as it was: versions, sources,
#' remotes, hashes, requirements. easypaper itself goes: it builds the
#' documents, the analysis does not use it, and installed from GitHub its
#' record names the account it came from. A file that is not valid JSON is
#' left alone.
#' @noRd
.lock_without_people <- function(f) {
  lock <- tryCatch(jsonlite::read_json(f, simplifyVector = FALSE),
                   error = function(e) NULL)
  if (!is.list(lock) || !is.list(lock$Packages)) return(invisible(f))
  people <- c("Author", "Authors@R", "Maintainer", "URL", "BugReports")
  lock$Packages$easypaper <- NULL
  lock$Packages <- lapply(lock$Packages, function(p) {
    if (is.list(p)) p[setdiff(names(p), people)] else p
  })
  jsonlite::write_json(lock, f, auto_unbox = TRUE, pretty = TRUE,
                       null = "null")
  invisible(f)
}

#' What identifies the authors of the manuscript: their names, whole and the
#' family name alone, their emails and ORCID, and their affiliations, whole
#' and the institution alone; and the accounts they are known by, which
#' often name nobody but are as good as a name -- the user part of each
#' email, which is often the GitHub one too, and the owner of the project's
#' GitHub repository. Nothing shorter than four characters, which would be
#' found everywhere; no user part shorter than six, which could be a word.
#' @noRd
.identifiers <- function() {
  own <- rmarkdown::yaml_front_matter(.master())
  a <- own$author
  if (!is.list(a) || !is.null(names(a))) a <- list(a)
  pool <- own$affiliations
  if (!is.null(pool) && (!is.list(pool) || !is.null(names(pool)))) pool <- list(pool)
  ids <- c(
    tryCatch(.author_names(), error = function(e) character(0)),
    vapply(.zenodo_creators(own), function(x) sub(",.*$", "", x$name), ""),
    unlist(lapply(a, function(x) if (is.list(x)) c(x$email, x$orcid))),
    unlist(.author_affiliations(own)),
    unlist(lapply(pool, function(p) if (is.list(p)) p$name)),
    .accounts(unlist(lapply(a, function(x) if (is.list(x)) x$email))))
  ids <- unique(trimws(as.character(ids)))
  ids[!is.na(ids) & nchar(ids) >= 4L]
}

#' The accounts the authors are known by: the user part of each email, six
#' characters or more, and the owner of every GitHub remote of the project.
#' @noRd
.accounts <- function(emails = character(0)) {
  user <- sub("@.*$", "", as.character(emails[grepl("@", emails)]))
  user <- user[nchar(user) >= 6L]
  remotes <- character(0)
  if (nzchar(Sys.which("git")) && dir.exists(.p(".git"))) {
    remotes <- tryCatch(suppressWarnings(system2(
      "git", c("-C", shQuote(.p()), "remote", "-v"),
      stdout = TRUE, stderr = FALSE)), error = function(e) character(0))
  }
  owner <- regmatches(remotes, regexpr("github[.]com[:/][^/ ]+", remotes))
  unique(c(user, sub("^github[.]com[:/]", "", owner)))
}

#' Which of `ids` each file of `dir` still holds, in its name or its text, as
#' a whole word. Binary files are not read. A named list: file -> ids.
#' @noRd
.names_left <- function(dir, ids) {
  if (!length(ids)) return(list())
  pats <- paste0("(?<![[:alnum:]])",
                 gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", ids),
                 "(?![[:alnum:]])")
  files <- list.files(dir, recursive = TRUE, all.files = TRUE)
  out <- lapply(files, function(f) {
    path <- file.path(dir, f)
    txt <- f
    size <- file.size(path)
    if (!is.na(size) && size > 0 && size < 50e6) {
      raw <- readBin(path, "raw", size)
      if (!any(raw == as.raw(0))) txt <- c(txt, rawToChar(raw))
    }
    hit <- vapply(pats, function(p) {
      any(grepl(p, txt, perl = TRUE, useBytes = TRUE))
    }, logical(1))
    ids[hit]
  })
  names(out) <- files
  Filter(length, out)
}

#' Read a dataspice .csv from the compendium, or NULL if it is not there.
#' @noRd
.spice <- function(dest, file) {
  f <- file.path(dest, "metadata", file)
  if (!file.exists(f)) return(NULL)
  d <- tryCatch(.read_meta(f, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(d) || !nrow(d)) NULL else d
}

#' Canned descriptions for the files every project produces. Anything else is
#' described by its own first comment line, so a script you add documents
#' itself here.
#' @noRd
.known_desc <- c(
  "dataspice.json"       = "Machine-readable metadata (Schema.org standard).",
  "attributes.csv"       = "Data dictionary: column names, descriptions and units for every data file.",
  "access.csv"           = "Registry of the files included in the dataset and their formats.",
  "biblio.csv"           = "Dataset-level information: title, description, temporal and spatial coverage.",
  "creators.csv"         = "Author information and affiliations.",
  "index_metadata.html"  = "OPEN THIS FILE in your web browser to view a visual map of all variables and units.",
  "index.html"           = "OPEN THIS FILE in your web browser to view a visual map of all variables and units.",
  "analysis_code.R"      = "Full statistical analysis of the manuscript, in the order it is executed. Extracted from the manuscript sources.",
  "setup.R"              = "Seed, colour palette and helper functions loaded before the analysis.",
  "sessionInfo.txt"      = "Exact versions of R, of every package and of Quarto used to produce the reported results."
)

#' First comment line of a script, used as its description.
#' @noRd
.first_comment <- function(f) {
  l <- readLines(f, warn = FALSE, n = 40)
  l <- l[grepl("^\\s*#", l)]
  l <- trimws(sub("^\\s*#+'?\\s*", "", l))
  l <- l[nzchar(l) & !grepl("^-{3,}|^={3,}", l)]
  if (length(l)) l[1] else ""
}

#' Describe a data file: its dataspice title if there is one, plus dimensions.
#' @noRd
.describe_data <- function(f, access) {
  dims <- tryCatch({
    d <- utils::read.csv(f, check.names = FALSE, stringsAsFactors = FALSE)
    sprintf("%d rows x %d columns", nrow(d), ncol(d))
  }, error = function(e) NA_character_)
  ttl <- NA_character_
  if (!is.null(access) && "fileName" %in% names(access) &&
      "name" %in% names(access)) {
    i <- match(basename(f), access$fileName)
    if (!is.na(i)) ttl <- access$name[i]
  }
  parts <- c(if (!is.na(ttl) && nzchar(ttl)) ttl, if (!is.na(dims)) dims)
  paste(parts, collapse = " -- ")
}

#' README.txt of the compendium, written from what the folder ACTUALLY holds.
#'
#' Nothing here is hard-coded to one paper: the title comes from the YAML of
#' manuscript.qmd, the dates from the dataspice metadata, and every file is
#' listed and described by inspecting it.
#' @noRd
.write_data_readme <- function(dest, blinded = TRUE) {
  own    <- rmarkdown::yaml_front_matter(.master())
  title  <- if (!is.null(own$title)) own$title else "Untitled"
  access <- .spice(dest, "access.csv")
  biblio <- .spice(dest, "biblio.csv")

  # Authors: never named when the submission is blinded.
  authors <- "Anonymous"
  if (!blinded) {
    authors <- tryCatch(paste(.author_names(), collapse = ", "),
                        error = function(e) "Anonymous")
  }

  # Date of data collection: dataspice startDate/endDate if they were filled in.
  dates <- NULL
  if (!is.null(biblio)) {
    sd <- if ("startDate" %in% names(biblio)) biblio$startDate[1] else NA
    ed <- if ("endDate"   %in% names(biblio)) biblio$endDate[1]   else NA
    sd <- if (!is.na(sd) && nzchar(sd)) substr(sd, 1, 4) else NA
    ed <- if (!is.na(ed) && nzchar(ed)) substr(ed, 1, 4) else NA
    if (!is.na(sd)) dates <- if (!is.na(ed) && ed != sd) paste0(sd, "-", ed) else sd
  }

  rule <- strrep("-", 72)
  sec  <- function(name, dir, describe) {
    fs <- sort(list.files(dir, all.files = FALSE))
    fs <- fs[!fs %in% c(".gitkeep", ".DS_Store", "README.md", "README.txt")]
    if (!length(fs)) return(c(name, "   (empty)", ""))
    c(name,
      unlist(lapply(fs, function(f) {
        d <- describe(file.path(dir, f))
        if (!nzchar(d)) sprintf("   - %s", f)
        else strwrap(sprintf("%s: %s", f, d), width = 76,
                     initial = "   - ", prefix = "     ")
      })),
      "")
  }

  n <- 0L; num <- function() { n <<- n + 1L; n }
  general <- c(
    "GENERAL INFORMATION", "",
    strwrap(sprintf("%d. Title: %s", num(), title), width = 76, exdent = 3),
    if (!is.null(dates)) sprintf("%d. Date of data collection: %s", num(), dates),
    sprintf("%d. Authors Information:", num()), "",
    paste0("   ", authors), ""
  )

  overview <- c(
    "FILE OVERVIEW", "",
    strwrap(paste("This repository holds the data, the metadata describing it and the",
                  "code that produced the results reported in the manuscript. It is",
                  "organized into three folders:"), width = 76), "",
    sec("A) data",
        file.path(dest, "data"),
        function(f) .describe_data(f, access)),
    sec("B) metadata",
        file.path(dest, "metadata"),
        function(f) {
          d <- .known_desc[basename(f)]
          if (is.na(d)) "" else unname(d)
        }),
    sec("C) scripts",
        file.path(dest, "scripts"),
        function(f) {
          d <- .known_desc[basename(f)]
          if (!is.na(d)) return(unname(d))
          if (grepl("[.]R$", f)) .first_comment(f) else ""
        }),
    strwrap(paste("Data are distributed in open formats: .csv where the table",
                  "allows it, and the original open format where converting it",
                  "would destroy it -- a GeoPackage, a NetCDF, a SQLite",
                  "database. None of it needs proprietary software to read.",
                  "The spreadsheets and statistical files some of it was",
                  "converted from are not part of this deposit: they stay in",
                  "the authors' project as the archive copy."),
            width = 76), ""
  )

  has_lock <- file.exists(file.path(dest, "renv.lock"))
  rproj    <- list.files(dest, pattern = "[.]Rproj$")
  rproj    <- if (length(rproj)) rproj[1] else "the .Rproj file"
  repro <- c(
    "REPRODUCIBILITY (SOFTWARE ENVIRONMENT)", "",
    if (has_lock) c(
      strwrap(paste("This project uses the R package 'renv' to make the statistical",
                    "analysis reproducible. The 'renv.lock' file lists the exact",
                    "version of every package used in this study."), width = 76), "",
      "To reconstruct the analysis environment:", "",
      sprintf("1. Open the project file ('%s') to launch RStudio.", rproj),
      "2. If 'renv' is not installed on your system, run in the R console:",
      "      install.packages(\"renv\")",
      "3. Restore the environment by running:",
      "      renv::restore()",
      strwrap(paste("(this reads 'renv.lock' and installs the recorded package",
                    "versions, without touching your own R library)."),
              width = 76, initial = "   ", prefix = "   "), "",
      strwrap(paste("Run 'scripts/analysis_code.R'. It sources 'scripts/setup.R'",
                    "and reproduces the analyses reported in the manuscript."),
              width = 76, initial = "4. ", prefix = "   "), ""
    ) else c(
      strwrap(paste("The versions of R, of every package and of Quarto used to",
                    "produce the reported results are recorded in",
                    "'scripts/sessionInfo.txt'."), width = 76), "",
      strwrap(paste("Run 'scripts/analysis_code.R'. It sources 'scripts/setup.R' and",
                    "reproduces the analyses reported in the manuscript."),
              width = 76), ""
    )
  )

  licence <- c(
    "LICENSE", "",
    strwrap(paste("Data and metadata: CC BY 4.0 (see LICENSE). Code: MIT (see",
                  "LICENSE-CODE). Both allow reuse with attribution; please cite the",
                  "associated publication."), width = 76), ""
  )

  writeLines(c(general, rule, "", overview, rule, "", repro, rule, "", licence),
             file.path(dest, "README.txt"))
  invisible(file.path(dest, "README.txt"))
}

# --- What is written by hand ------------------------------------------------------------

#' Cover letter with the usual structure, and what the project already knows
#' filled in: the date it is written, the title of the manuscript, the
#' corresponding author who signs it, and the DOI of the data once
#' deposit_zenodo() has reserved it. The rest is in brackets, to write.
#' Never overwrites an existing one.
#' @noRd
.write_cover_letter <- function(dest, journal_name) {
  if (file.exists(dest)) {
    message("Cover letter already exists, left untouched: ", basename(dest))
    return(invisible(dest))
  }
  tmp <- .p("tmp_cover_letter.qmd")
  on.exit(unlink(tmp), add = TRUE)
  yml <- list(title = sprintf("Cover letter -- %s", journal_name),
              format = list(docx = list(
                `reference-doc` = .word_template("letter"))))
  own   <- rmarkdown::yaml_front_matter(.master())
  title <- trimws(paste(unlist(own$title), collapse = " "))
  if (!nzchar(title)) title <- "[TITLE]"
  doi   <- .config("data-doi")
  data  <- if (length(doi) && nzchar(doi[1])) paste0("https://doi.org/", doi[1])
           else "[repository DOI]"
  writeLines(c(
    "---", .as_yaml(yml), "---", "",
    .letter_date(), "", "Dear Editor,", "",
    "We are pleased to submit our manuscript entitled",
    sprintf("\"%s\" for consideration as [article type] in *%s*.", title,
            journal_name), "",
    "**What we did.** [One or two sentences: question and approach.]", "",
    "**What we found.** [The main result, with the number.]", "",
    sprintf("**Why %s.** [Why it fits the scope and the readership.]",
            journal_name), "",
    "The manuscript is original, is not under consideration elsewhere, and all",
    "authors have approved the submission. We declare no conflict of interest.",
    paste0("Data and code are available at ", data, "."), "",
    "Suggested reviewers: [Name, affiliation, e-mail] (x3).", "",
    "Yours sincerely,", "", .signature(own)
  ), tmp)
  quarto::quarto_render(tmp, output_format = "docx", as_job = FALSE, quiet = TRUE)
  file.rename(sub("\\.qmd$", ".docx", tmp), dest)
  invisible(dest)
}

#' Today, as a letter dates itself: "3 October 2026". The month in English
#' whatever the locale of R, since the letter is in English.
#' @noRd
.letter_date <- function(date = Sys.Date()) {
  paste(as.integer(format(date, "%d")), month.name[as.integer(format(date, "%m"))],
        format(date, "%Y"))
}

#' Who signs the letter: the corresponding author -- the first one marked
#' `corresponding: true`, or else the first author -- on behalf of the rest
#' when there are others.
#' @noRd
.signature <- function(own) {
  a <- own$author
  if (is.character(a)) a <- as.list(a)
  if (is.list(a) && !is.null(names(a))) a <- list(a)
  if (!length(a)) return("[Corresponding author, on behalf of all authors]")
  corr <- vapply(a, function(x) is.list(x) && isTRUE(x[["corresponding"]]),
                 logical(1))
  who <- .person_name(a[[if (any(corr)) which(corr)[1] else 1L]])
  if (is.null(who) || !nzchar(trimws(who))) {
    return("[Corresponding author, on behalf of all authors]")
  }
  paste0(trimws(who), if (length(a) > 1L) ", on behalf of all authors")
}

#' The DOI of the data written into the cover letters already in
#' submission/, where they still say `[repository DOI]`. A letter edited in
#' Word may have split the words; it is then left as it is. Returns the
#' letters changed.
#' @noRd
.fill_doi_letters <- function(doi) {
  letters <- list.files(.p("submission"), "^cover_letter_.*[.]docx$",
                        recursive = TRUE, full.names = TRUE)
  changed <- character(0)
  for (f in letters) {
    # The order of the parts is the letter's own, so [Content_Types].xml
    # stays first, as in .repair_docx().
    parts <- tryCatch(zip::zip_list(f)$filename, error = function(e) NULL)
    if (!"word/document.xml" %in% parts) next
    d <- file.path(tempdir(), paste0("letter_", basename(f)))
    unlink(d, recursive = TRUE)
    utils::unzip(f, exdir = d)
    x <- file.path(d, "word", "document.xml")
    xml <- readChar(x, file.size(x), useBytes = TRUE)
    new <- gsub("[repository DOI]", paste0("https://doi.org/", doi), xml,
                fixed = TRUE, useBytes = TRUE)
    if (!identical(new, xml)) {
      writeChar(new, x, eos = NULL, useBytes = TRUE)
      zip::zip(zipfile = normalizePath(f), files = parts, root = d,
               mode = "mirror")
      changed <- c(changed, file.path(basename(dirname(f)), basename(f)))
    }
    unlink(d, recursive = TRUE)
  }
  changed
}

#' @noRd
.write_checklist <- function(dest, journal_name, label, blinded = TRUE) {
  writeLines(c(
    sprintf("# Submission checklist -- %s", journal_name), "",
    "Generated by `make_submission()`. Nothing below is produced automatically.", "",
    "## Before submitting", "",
    sprintf("- [ ] Cover letter written (`cover_letter_%s.docx`).", label),
    if (blinded) "- [ ] Title page: running head, word count, number of figures and tables,"
    else "- [ ] Front page of `main_*.docx`: running head, word count, number of figures and tables,",
    "      ORCID of every author, funding.",
    "- [ ] Suggested reviewers (usually 3, with no conflict of interest).",
    "- [ ] Check the figure format the journal requires (TIFF/EPS/PDF, minimum",
    "      dpi, width in mm) and regenerate if needed:",
    "      `make_submission(figure_format = \"png\")`.",
    "- [ ] `renv.lock` present in `data_and_code/`: without it the package",
    "      versions are not recorded. `make_submission()` writes it unless",
    "      called with `snapshot = FALSE`.",
    "- [ ] Everything in `data_and_code/data/` belongs to this paper.",
    "      `check_data()` lists the files nothing reads: they travel to the",
    "      repository and into the metadata all the same.",
    "- [ ] Upload `data_and_code.zip` to Zenodo/Dryad and put the DOI in the",
    "      Data availability statement of the manuscript. `deposit_zenodo()`",
    "      uploads it as a Zenodo draft and writes its reserved DOI in for you.",
    if (blinded) c(
      "- [ ] If the journal asks for the data at review, send the reviewers",
      "      `data_and_code_blinded.zip`: the same compendium with no author in",
      "      it. `data_and_code.zip` is signed: it is the one deposited."),
    "- [ ] `git tag submission-1`", "",
    "## Journal dependent", "",
    "- [ ] Graphical abstract / highlights.",
    if (blinded) c(
      "- [ ] Double blind: `main_*.docx` carries the title and no author (it is",
      "      generated with blind = TRUE). But review self-citations of the",
      "      kind \"in our previous study (Author et al.)\", which also identify",
      "      you."),
    "- [ ] Line numbers and line spacing as the journal asks: they come from",
    "      `make_submission(line_numbers = , line_spacing = ,",
    "      suppl_line_spacing = )` -- numbered and double-spaced by default.", "",
    "## Regenerable", "",
    "Everything else is rebuilt by `make_submission()`. The cover letter is",
    "never overwritten."
  ), dest)
  invisible(dest)
}

#' What goes where, written into the preprint deposit itself.
#' @noRd
.write_preprint_readme <- function(dest, label) {
  own <- rmarkdown::yaml_front_matter(.master())
  title <- if (!is.null(own$title)) own$title else "Untitled"
  writeLines(c(
    sprintf("# Preprint deposit: %s", title),
    "",
    sprintf("Built by `make_preprint()` on %s. Two destinations, one folder.",
            format(Sys.Date())),
    "",
    "## To the preprint server (bioRxiv, EcoEvoRxiv, PCI Ecology...)",
    "",
    sprintf("- `manuscript/preprint_%s.pdf` -- the manuscript, signed: the", label),
    "  authors are on the front page. A preprint is not reviewed blind, so this",
    "  is deliberately NOT the blinded document `make_submission()` builds.",
    "- `manuscript/supporting_information*.pdf` -- upload as supplementary files.",
    "- `manuscript/figures/` -- only if the server asks for figures separately.",
    "  The PDF already embeds them at full resolution.",
    "",
    "## To the data repository (Zenodo, Dryad, figshare...)",
    "",
    "- `data_and_code.zip` -- data, metadata, the analysis code, the licences",
    "  and `renv.lock`. It has its own README, written from what it holds.",
    "",
    "## Before you press submit",
    "",
    "- [ ] Deposit the data and code FIRST: you need its DOI to cite it in the",
    "      manuscript, and editing a preprint after posting is a new version.",
    "      `deposit_zenodo()` reserves it on a Zenodo draft.",
    "- [ ] The DOI, written into the manuscript (\"Data and code are available",
    "      at https://doi.org/...\") and rebuilt before uploading the PDF.",
    "- [ ] Licences: the code travels MIT, the text and data CC BY 4.0. Say so",
    "      in the repository's licence field, which is a separate declaration.",
    "- [ ] ORCID for every author, on the server's form.",
    "- [ ] Competing interests and funding, if the server asks for them.",
    "- [ ] Check the journal you plan to submit to accepts preprints. Most",
    "      ecology journals do; a few still do not, and posting first would",
    "      close that door."
  ), dest)
  invisible(dest)
}
