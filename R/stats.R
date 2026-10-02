# ---------------------------------------------------------------------------
# The length of the manuscript, counted the way a journal counts it.
# ---------------------------------------------------------------------------

#' A summary of the manuscript
#'
#' What a journal asks for on its submission form: the characters of the
#' title and of the short title when there is one, with and without spaces;
#' the words of the abstract; the keywords;
#' the words of the main text, without and with its reference list; the
#' references cited; and the figures and tables of the paper and of its
#' supplement. Every render and
#' every `make_*()` prints it when it is done, once; this prints it on its
#' own.
#'
#' Words are counted the way Word counts them in the rendered document, not
#' in the source: a citation counts as the text the journal's style prints
#' for it -- `[@smith2020]` as "(Smith 2020)" -- a cross-reference as "Figure
#' 1", and code, comments and markup not at all. The abstract is the
#' `# Abstract` section without its keywords line; the main text is every
#' section from the one after the abstract to the reference list, less the
#' statements at the end -- acknowledgements, funding, author contributions,
#' conflicts of interest, data availability, ethics -- whatever they are
#' called: Introduction to Discussion, in the template. The
#' reference list is the one the paper prints, in the journal's style. The
#' value of inline R code is not known until it runs, and counts as one word.
#'
#' @param quiet `TRUE` returns the counts without printing them.
#' @param path The project, or any folder inside it. The working directory by
#'   default, which is the project root once its `.Rproj` is open.
#' @return A named integer vector, invisibly when printed: `title_chars`,
#'   `title_chars_no_spaces`, `short_title_chars` and
#'   `short_title_chars_no_spaces` (`NA` without one),
#'   `abstract_words`, `keywords`, `main_words`,
#'   `main_words_with_refs`, `references`, `figures`, `tables`,
#'   `suppl_figures` and
#'   `suppl_tables`.
#' @export
#' @examples
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir, title = "Ant colonies", git = FALSE)
#' if (rmarkdown::pandoc_available()) manuscript_stats(path = dir)
#' unlink(dir, recursive = TRUE)
manuscript_stats <- function(quiet = FALSE, path = ".") {
  .enter_project(path)
  .check_flag(quiet, "quiet")
  master <- readLines(.master(), warn = FALSE)
  own    <- rmarkdown::yaml_front_matter(.master())
  heads  <- .top_headings(master)

  title <- paste(own$title, collapse = " ")
  abstract <- .section_text(master, "Abstract")
  abstract <- abstract[!.is_keywords_line(abstract)]
  i <- match("Abstract", heads)
  j <- match("References", heads)
  if (is.na(j)) j <- length(heads) + 1L
  main <- if (is.na(i) || i + 1L >= j) character(0) else heads[(i + 1L):(j - 1L)]
  main <- main[!.not_main_text(main)]
  main_text <- unlist(lapply(main, function(h) .section_text(master, h)))

  # The paper and its supplement, which has a reference list of its own:
  # the paper's is every entry cited outside it.
  files <- c(.master(), .section_files())
  suppl <- files %in% .suppl_files()
  cited <- unique(Filter(Negate(.is_crossref),
                         unlist(lapply(files[!suppl], .at_keys))))
  floats <- unique(.crossref_labels(files[!suppl]))
  sfloats <- unique(.crossref_labels(files[suppl]))
  main_words <- .count_words(main_text)
  short <- .short_title(own)
  out <- c(title_chars           = nchar(title),
           title_chars_no_spaces = nchar(gsub("\\s", "", title)),
           short_title_chars     = if (is.null(short)) NA_integer_ else nchar(short),
           short_title_chars_no_spaces =
             if (is.null(short)) NA_integer_ else nchar(gsub("\\s", "", short)),
           abstract_words        = .count_words(abstract),
           keywords              = length(.keywords()),
           main_words            = main_words,
           main_words_with_refs  = main_words + .reference_list_words(cited),
           references            = length(cited),
           figures               = sum(startsWith(floats, "fig-")),
           tables                = sum(startsWith(floats, "tbl-")),
           suppl_figures         = sum(startsWith(sfloats, "sfig-")),
           suppl_tables          = sum(startsWith(sfloats, "stbl-")))
  out <- vapply(out, function(x) as.integer(x), integer(1))
  if (quiet) return(out)
  message(.stats_text(out))
  invisible(out)
}

#' The headings that are not main text, whatever a project calls them: the
#' keywords, and the statements at the end -- acknowledgements, funding,
#' author contributions, conflicts of interest, data availability, ethics --
#' whether or not a blinded submission moves them.
#' @noRd
.not_main_text <- function(h) {
  rx <- paste0("^key ?words?$|acknowledg|funding|credit|author contribution|",
               "contribution statement|conflict|competing interest|",
               "data (availability|accessibility)|ethic")
  grepl(rx, trimws(h), ignore.case = TRUE) |
    tolower(trimws(h)) %in% tolower(.blinded_sections())
}

#' The counts, one to a line: what it is, the number right-aligned, and its
#' unit, so the number a submission form asks for is read off at a glance.
#' @noRd
.stats_text <- function(s) {
  rows <- list(
    c("Title",                  s[["title_chars"]],           "characters"),
    c("Title, without spaces",  s[["title_chars_no_spaces"]], "characters"),
    # Only when the manuscript has one.
    if (!is.na(s[["short_title_chars"]]))
      c("Short title",          s[["short_title_chars"]],     "characters"),
    if (!is.na(s[["short_title_chars"]]))
      c("Short title, without spaces", s[["short_title_chars_no_spaces"]],
        "characters"),
    c("Abstract",               s[["abstract_words"]],        "words"),
    c("Keywords",               s[["keywords"]],              ""),
    c("Main text",              s[["main_words"]],            "words"),
    c("Main text + references", s[["main_words_with_refs"]],  "words"),
    c("References",             s[["references"]],            ""),
    c("Figures",                s[["figures"]],               ""),
    c("Tables",                 s[["tables"]],                ""),
    c("Supplementary figures",  s[["suppl_figures"]],         ""),
    c("Supplementary tables",   s[["suppl_tables"]],          ""))
  rows <- Filter(Negate(is.null), rows)
  what <- vapply(rows, `[`, "", 1L)
  n    <- vapply(rows, `[`, "", 2L)
  unit <- vapply(rows, `[`, "", 3L)
  lines <- sprintf("  %-*s  %*s %s", max(nchar(what)), what, max(nchar(n)), n,
                   unit)
  paste(c("Manuscript summary", sub("\\s+$", "", lines)), collapse = "\n")
}

#' Print the length of the manuscript when a render or a make_*() is done:
#' once, at the end of the outermost call -- render_all() renders four
#' documents, and make_submission() renders a supplement after its main text. Inside one of
#' those it says nothing until `force`, which the outer call passes when it is
#' done. A count that fails says nothing: it is never worth a failed render.
#' @noRd
.report_length <- function(force = FALSE) {
  if (isTRUE(.ep$batch) && !force) return(invisible(NULL))
  s <- suppressWarnings(tryCatch(manuscript_stats(quiet = TRUE),
                                 error = function(e) NULL))
  if (!is.null(s)) message("\n", .stats_text(s))
  invisible(s)
}

#' Hold the length back for as long as the calling function runs: the renders
#' it calls say nothing, and it prints the length itself when it is done.
#' TRUE for the outermost call, which is the one that prints; FALSE for one
#' nested in another.
#' @noRd
.batch <- function(envir = parent.frame()) {
  if (isTRUE(.ep$batch)) return(invisible(FALSE))
  .ep$batch <- TRUE
  do.call(base::on.exit, list(quote(.ep$batch <- NULL), add = TRUE),
          envir = envir)
  invisible(TRUE)
}

#' Words of the reference list these keys make, in the journal's style.
#' Without pandoc, nothing can be rendered and nothing is counted.
#' @noRd
.reference_list_words <- function(keys) {
  if (!length(keys)) return(0L)
  plain <- .pandoc_plain(c("---", paste0("nocite: '", paste0("@", keys, collapse = ", "),
                                         "'"), "---", ""),
                         bibliography = TRUE)
  if (is.null(plain)) return(0L)
  .words_of(plain)
}

#' The top-level headings of manuscript.qmd, outside code chunks.
#' @noRd
.top_headings <- function(l) {
  fence <- grepl("^\\s*```", l)
  inside <- (cumsum(fence) %% 2 == 1) | fence
  h <- l[!inside & grepl("^# ", l)]
  trimws(sub("^#\\s+", "", sub("\\s*\\{[^}]*\\}\\s*$", "", h)))
}

#' The text of one top-level section of manuscript.qmd, includes resolved,
#' heading left out.
#' @noRd
.section_text <- function(master, heading) {
  blk <- .section_block(master, heading)
  if (!length(blk)) return(character(0))
  .expand_includes_text(blk[-1])
}

#' The keywords line under an abstract: "**Keywords:** ..." and its kin.
#' @noRd
.is_keywords_line <- function(l) {
  grepl("^\\s*key ?words?\\s*[:.]", gsub("[*_]", "", l), ignore.case = TRUE,
        perl = TRUE)
}

#' Words of markdown, as Word counts them in the rendered document.
#'
#' Code chunks, comments, shortcodes and markup go; inline R code is one
#' word; a cross-reference is "Figure 1"; citations are rendered by pandoc in
#' the journal's style. Without pandoc each citation counts as "(Author
#' Year)", and what is left of the markup is taken out by hand.
#' @noRd
.count_words <- function(md) {
  md <- md[!is.na(md)]
  if (!length(md)) return(0L)
  fence <- grepl("^\\s*```", md)
  md <- md[!((cumsum(fence) %% 2 == 1) | fence)]
  txt <- paste(md, collapse = "\n")
  txt <- gsub("(?s)<!--.*?-->", "", txt, perl = TRUE)
  txt <- gsub("\\{\\{<.*?>\\}\\}", "", txt, perl = TRUE)
  txt <- gsub("`r [^`]*`", "X", txt, perl = TRUE)
  xref <- paste0("(?<![\\p{L}\\p{N}_\\\\])-?@(?:", paste(CROSSREF_PREFIXES,
                 collapse = "|"), ")-[A-Za-z0-9_:.-]*[A-Za-z0-9_]")
  txt <- gsub(xref, "Ref 1", txt, perl = TRUE)
  if (!nzchar(trimws(txt))) return(0L)
  plain <- .pandoc_plain(txt)
  if (is.null(plain)) {
    plain <- gsub("\\[[^]]*@[^]]*\\]", "(Author Year)", txt, perl = TRUE)
    plain <- gsub("[#*_>`~|:]|\\{[^}]*\\}", " ", plain, perl = TRUE)
  }
  .words_of(plain)
}

#' Word's count of plain text: every run of characters between spaces -- "&"
#' and a spaced dash too -- but not the bullets and numbers of a list.
#' @noRd
.words_of <- function(plain) {
  plain <- sub("^\\s*(?:[-*+]|[0-9]+[.)])\\s+", "", plain, perl = TRUE)
  w <- unlist(strsplit(plain, "\\s+"))
  sum(nzchar(w))
}

#' Markdown to plain text with the citations rendered in the manuscript's
#' style, and, with `bibliography = TRUE`, the reference list they make.
#' NULL when pandoc is not there.
#' @noRd
.pandoc_plain <- function(txt, bibliography = FALSE) {
  if (!rmarkdown::pandoc_available()) return(NULL)
  bib <- .bib_paths()
  bib <- bib[file.exists(bib)]
  csl <- tryCatch(.csl_path(.resolve_journal(NULL)), error = function(e) NULL)
  src <- tempfile(fileext = ".md")
  out <- tempfile(fileext = ".txt")
  on.exit(unlink(c(src, out)), add = TRUE)
  writeLines(enc2utf8(txt), src, useBytes = TRUE)
  args <- c(shQuote(src), "-f", "markdown", "-t", "plain", "--wrap=none",
            "-o", shQuote(out))
  if (length(bib)) {
    args <- c(args, "--citeproc", paste0("--bibliography=", shQuote(bib)),
              if (!bibliography) "--metadata=suppress-bibliography:true")
    if (!is.null(csl) && file.exists(csl)) args <- c(args, paste0("--csl=", shQuote(csl)))
  }
  status <- suppressWarnings(system2(rmarkdown::pandoc_exec(), args,
                                     stdout = FALSE, stderr = FALSE))
  if (!identical(as.integer(status), 0L) || !file.exists(out)) return(NULL)
  readLines(out, warn = FALSE, encoding = "UTF-8")
}
