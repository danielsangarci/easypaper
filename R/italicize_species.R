# ---------------------------------------------------------------------------
# italicize_species() -- scientific names in italics, in any reference list.
#
# Every render runs it on the project's bibliography first. It stands on its
# own -- base R, jsonlite, and pandoc, which Quarto and RStudio both carry --
# and its helpers carry the .sp_ prefix.
#
# Why it is needed at all: citeproc does not know which words are scientific
# names, so a title reaches the reference list with "Pinus halepensis" in
# roman. Worse, pandoc lowercases the titles of a .bib it takes for English
# ("pinus halepensis"), and a title-case style capitalises the epithet
# ("Pinus Halepensis"). No LaTeX markup inside the .bib gets italics and
# protected case at the same time, so the bibliography is converted to
# CSL-JSON and every name is marked there as
# <i><span class="nocase">Pinus halepensis</span></i>, which citeproc honours
# in every style and every output format.
# ---------------------------------------------------------------------------

#' Set the scientific names of a bibliography in italics
#'
#' Reference lists come out of Quarto and R Markdown with genus and species
#' names in roman, because citeproc cannot tell a scientific name from any
#' other word. This rewrites a bibliography so that it can: every genus,
#' species, abbreviation (*Q. suber*) and subspecies in the titles is found,
#' checked against the GBIF Backbone Taxonomy, and marked in italics in a copy
#' of the bibliography that you then hand to Quarto or R Markdown instead of
#' the original. The original is only ever read.
#'
#' Inside an easypaper project there is nothing to call: every `render_*()`
#' runs this on the project's bibliography first. This is the same function,
#' for a bibliography anywhere else. Point the document at the file it writes:
#'
#' ```yaml
#' bibliography: references_italic.json
#' ```
#'
#' ```r
#' # first chunk of the .qmd or .Rmd: it runs before pandoc reads the file
#' easypaper::italicize_species("references.bib", "references_italic.json")
#' ```
#'
#' @section How names are found:
#' Nothing has to be listed by hand. Anything in a title shaped like a
#' scientific name is looked up in GBIF, and in the English Wikipedia where a
#' word could also be something else:
#'
#' * **Genus and epithet** ("Quercus suber"): the species exists in GBIF, or
#'   its genus and its epithet both do -- so a combination GBIF lacks still
#'   counts. An epithet written in capitals ("Helicobacter Pylori") is
#'   lowercased.
#' * **New species** ("Haemoproteus trarotraro n. sp."): a known genus followed
#'   by `n. sp.`, `sp. nov.` or `comb. nov.`.
#' * **Abbreviations** ("Q. suber"): the epithet exists in GBIF; the genus need
#'   not be spelled out anywhere.
#' * **Subspecies and varieties** ("Quercus ilex subsp. ballota", "Epilachna
#'   sparsa orientalis"): the infraspecific epithet in italics, the rank
#'   (`subsp.`, `var.`, `f.`) in roman.
#' * **A genus on its own** ("Wolbachia infections", "Quercus spp."): it
#'   appears in a binomial elsewhere in the bibliography, is followed by
#'   `sp.`, `spp.` or `species` or preceded by "genus", or Wikipedia describes
#'   it as a genus. That last check is what keeps "China", "Andes" and
#'   "America" -- all animal genera in GBIF -- in roman.
#' * **A genus that is also an English common name** (gorilla, bison, lynx,
#'   eucalyptus, according to GBIF's vernacular names): only in italics where
#'   the capital says it is the genus, halfway through a sentence-case title
#'   ("Seasonal diet of Gorilla in Gabon"). At the start of a title, or in a
#'   title-case one ("Gorilla Conservation in Africa"), the capital says
#'   nothing and the word is read as the common name.
#'
#' Higher taxa, virus names, genes and Latin phrases (*in vitro*) are left
#' alone: they are not genera or species.
#'
#' @section Doubtful cases:
#' When a word could be a genus and the title cannot tell -- a common name in
#' a position that says nothing, a word Wikipedia gives several meanings
#' ("Iris", "Rosa"), a binomial GBIF does not list -- it is left in roman and
#' reported, with the line of the file it is on and what to write there. The
#' mark is made in the bibliography itself and affects that reference only:
#'
#' * in a `.bib`: `\textit{Gorilla}` (or `\emph{}`) for italics,
#'   `\textup{Gorilla}` (or `\textrm{}`, `\textnormal{}`) for roman;
#' * in CSL-JSON: `<i>Gorilla</i>` and
#'   `<span style="font-style:normal;">Gorilla</span>`.
#'
#' A marked word is not reported again.
#'
#' @section The cache, and working offline:
#' Every answer from GBIF and Wikipedia is kept in `cache`, so only a name
#' never seen before needs a connection: the first run over a hundred new
#' references takes a couple of minutes, the next ones a fraction of a second.
#' Without a connection nothing fails: the cache is used, whatever could not be
#' checked is left in roman, and a warning says so. What could not be checked
#' is not written to the cache, so running again online completes it.
#' `options(easypaper.species_offline = TRUE)` works that way on purpose, with
#' a connection or without: nothing is looked up, and only the cache answers.
#'
#' The cache is small, about 5 KB per hundred references. Kept in git beside
#' the bibliography, it makes the result the same on every computer, with or
#' without a connection, and years later however GBIF and Wikipedia change.
#' That is where an easypaper project keeps it: `references/species_cache.rds`.
#'
#' @param input The bibliography to read: a `.bib` (BibTeX or BibLaTeX) or a
#'   `.json` (CSL-JSON, as Zotero exports it).
#' @param output The CSL-JSON file to write, which is the one the document must
#'   name in `bibliography:`. By default beside `input`, ending in
#'   `_italic.json`.
#' @param names Names to set in italics whatever GBIF says, for the rare one it
#'   does not know: a species ("Pinus halepensis"), an abbreviation
#'   ("Q. ruber") or a genus on its own ("Quercus"). Rarely needed.
#' @param exclude Names found that must stay in roman.
#' @param gbif `FALSE` looks nothing up, and only `names` is set in italics.
#' @param keep_case `TRUE`, the default, keeps every title exactly as the
#'   bibliography writes it, whatever the style. `FALSE` lets pandoc and the
#'   style change it the way they normally would: pandoc lowercases the titles
#'   of a `.bib`, a style like Chicago capitalises every word. Use `protect`
#'   then for the words that must keep their form. Scientific names keep theirs
#'   either way.
#' @param protect Words or phrases whose capitals are kept in any style:
#'   "Spain", "Mediterranean", "DNA".
#' @param cache The `.rds` file where the answers of GBIF and Wikipedia are
#'   kept, or `NULL` to keep none. By default one file in the user's cache
#'   directory ([tools::R_user_dir()]), shared by every bibliography.
#' @param fields The CSL fields of each reference to look into. A
#'   `container-title` is only read when it is a book's, the one a chapter
#'   belongs to: a journal's name is never touched.
#' @param quiet `TRUE` says nothing, except when there was no connection: that
#'   warning is always raised, because the result may then be incomplete.
#' @return The path of `output`, invisibly, with three attributes:
#'   `italicized`, the names set in italics; `doubtful`, a data frame of the
#'   cases left for you to decide (`id`, `word`, `reason`, `line`); and
#'   `offline`, `TRUE` when something could not be looked up.
#' @seealso [create_paper()], whose projects run this before every render.
#' @export
#' @examples
#' # A CSL-JSON bibliography, as Zotero exports it. With gbif = FALSE nothing
#' # is looked up, and only the names given are set in italics.
#' refs <- file.path(tempdir(), "refs.json")
#' writeLines('[{"id": "perez2020", "type": "article-journal",
#'   "title": "Effects of fire on Pinus halepensis regeneration"}]', refs)
#' out <- italicize_species(refs, names = "Pinus halepensis", gbif = FALSE)
#' jsonlite::read_json(out)[[1]]$title
#' unlink(c(refs, out))
#'
#' # The real thing: a .bib, every name looked up in GBIF. Needs pandoc (it
#' # comes with Quarto and RStudio) and, the first time, a connection:
#' #   italicize_species("references.bib", "references_italic.json")
italicize_species <- function(input,
                              output = NULL,
                              names = NULL,
                              exclude = NULL,
                              gbif = TRUE,
                              keep_case = TRUE,
                              protect = NULL,
                              cache = .sp_default_cache(),
                              fields = c("title", "title-short", "container-title",
                                         "collection-title", "original-title"),
                              quiet = FALSE) {
  if (!is.character(input) || length(input) != 1L || !file.exists(input)) {
    stop("`input` must be the path of a bibliography that exists.", call. = FALSE)
  }
  told <- is.null(output)
  if (told) output <- sub("\\.[^.]+$", "_italic.json", input)
  ext <- tolower(tools::file_ext(input))

  # 1. Read the bibliography. `items` is what gets written; `raw` is the text
  #    of each field as the file writes it -- capitals included -- which is
  #    where names are found, because pandoc may have lowercased `items`.
  #    `marks` holds the words marked by hand as italic (\textit{}) or roman
  #    (\textup{}) in each reference.
  if (ext == "bib") {
    items <- .sp_bib_to_csl(input, keep_case)
    raw <- .sp_bib_raw_fields(input)
    marks <- attr(raw, "marks")
  } else if (ext == "json") {
    items <- jsonlite::read_json(input, simplifyVector = FALSE)
    ids <- vapply(items, function(it) as.character(it$id), "")
    vals <- lapply(items, function(it) {
      as.character(unlist(it[.sp_fields_of(it, fields)], use.names = FALSE))
    })
    raw <- structure(lapply(vals, function(v) gsub("<[^>]+>", "", v)), names = ids)
    marks <- structure(lapply(vals, function(v) list(
      italic = .sp_marked_words(v, "<i>([^<]*)</i>"),
      roman = .sp_marked_words(v, '<span style="font-style: ?normal;?">([^<]*)</span>')
    )), names = ids)
  } else {
    stop("Cannot read a .", ext, " bibliography: give a .bib or a .json ",
         "(CSL-JSON).", call. = FALSE)
  }
  raw <- lapply(raw, .sp_squish)

  # 2. The accepted names: the ones given, plus the ones GBIF confirms.
  names <- .sp_squish(names)
  exclude <- .sp_squish(exclude)
  is_abbr <- grepl("^[A-Z]\\. ", names)
  abbrevs <- .sp_binomial(names[is_abbr])
  species <- .sp_binomial(names[!is_abbr & grepl(" ", names)])
  genera <- names[!grepl(" ", names)]
  forced <- genera  # a genus given in `names` is always in italics
  ambiguous <- character()
  trinomials <- character()
  unverified <- character()
  .sp_state$offline <- FALSE
  .sp_state$unresolved <- character()
  .sp_state$asked <- character()

  if (gbif) {
    look <- function(type, x) .sp_lookup(type, x, cache, quiet) %in% c("yes", "common")

    # "Quercus suber": the species is in GBIF, or its genus and epithet are.
    cands <- setdiff(unique(unlist(lapply(raw, .sp_binomial_candidates))),
                     c(species, exclude))
    ok <- look("sp", cands)
    rest <- cands[!ok]
    rest <- rest[.sp_latin_like(sub(".* ", "", rest))]
    rest <- rest[look("gen", sub(" .*", "", rest))]
    rest <- rest[look("ep", sub(".* ", "", rest))]
    species <- c(species, cands[ok], rest)

    # "Q. suber": the epithet is in GBIF.
    cands <- setdiff(unique(unlist(lapply(raw, .sp_abbrev_candidates))),
                     c(abbrevs, exclude))
    known <- paste0(substr(species, 1, 1), ". ", sub(".* ", "", species))
    rest <- setdiff(cands, known)
    abbrevs <- c(abbrevs, intersect(cands, known),
                 rest[look("ep", sub(".* ", "", rest))])

    # "Quercus spp.", "Oenanthe species", "the genus Quercus".
    cands <- setdiff(unique(unlist(lapply(raw, .sp_genus_sp_candidates))),
                     c(genera, exclude))
    genera <- c(genera, cands[look("gen", cands)])

    # "Wolbachia infections": any capitalised word Wikipedia describes as a
    # genus -- or has no page for, so it is neither a place nor a common word --
    # and GBIF lists as one.
    cands <- setdiff(unique(unlist(lapply(raw, .sp_capitalized_words))),
                     c(genera, sub(" .*", "", species), exclude))
    wp <- .sp_lookup("wp", cands, cache, quiet)
    yes <- cands[wp %in% c("yes", "missing")]
    genera <- c(genera, yes[look("gen", yes)])
    # A word with several meanings ("Iris", "Rosa") is a genus when every one
    # of them is a living thing ("Tribolium": a beetle and a plant). Otherwise
    # it is only set in italics with a clear sign, and reported when there is
    # none.
    amb <- cands[wp %in% "ambig"]
    amb <- amb[look("gen", amb)]
    taxa <- .sp_lookup("wpt", amb, cache, quiet) %in% "yes"
    genera <- c(genera, amb[taxa])
    ambiguous <- amb[!taxa]

    # "Helicobacter Pylori": an epithet in capitals, in a title-case title,
    # after a known genus. Accepted like any binomial, written in lowercase.
    known <- unique(c(genera, sub(" .*", "", species)))
    cands <- setdiff(unique(unlist(lapply(raw, .sp_cap_epithet_candidates, genera = known))),
                     c(species, exclude))
    ok <- look("sp", cands)
    rest <- cands[!ok]
    rest <- rest[.sp_latin_like(sub(".* ", "", rest))]
    species <- c(species, cands[ok], rest[look("ep", sub(".* ", "", rest))])

    # "Epilachna sparsa orientalis": a zoological subspecies, with no rank.
    # The subspecies is in GBIF, or the third word is a known, Latin-looking
    # epithet ("Helicobacter pylori infection" is not).
    cands <- setdiff(unique(unlist(lapply(raw, .sp_trinomial_candidates, species = species))),
                     exclude)
    ok <- look("ssp", cands)
    rest <- cands[!ok]
    rest <- rest[.sp_latin_like(sub(".* ", "", rest))]
    trinomials <- c(cands[ok], rest[look("ep", sub(".* ", "", rest))])

    # "Haemoproteus trarotraro": a known genus and an epithet GBIF does not
    # list. With "n. sp." it is a new species; without, a doubtful case -- if
    # the epithet looks Latin and is not a word with an article of its own
    # ("Anopheles malaria" is not).
    known <- unique(c(genera, sub(" .*", "", species)))
    cands <- unique(unlist(lapply(raw, .sp_binomial_candidates)))
    cands <- setdiff(cands[sub(" .*", "", cands) %in% known], c(species, exclude))
    nov <- vapply(cands, function(sp) any(vapply(raw, function(f) any(grepl(
      paste0("(*UCP)\\b", .sp_loose(sp),
             "\\s+(n\\.\\s*sp\\.|sp\\.\\s*n(ov)?\\.|comb\\.\\s*nov\\.)"),
      f, perl = TRUE)), TRUE)), TRUE)
    species <- c(species, cands[nov])
    cands <- cands[!nov & .sp_latin_like(sub(".* ", "", cands))]
    ep <- sub(".* ", "", cands)
    wp <- .sp_lookup("wp", paste0(toupper(substr(ep, 1, 1)), substring(ep, 2)),
                     cache, quiet)
    unverified <- cands[wp %in% c("missing", "yes")]
  }
  species <- setdiff(unique(species), exclude)
  abbrevs <- setdiff(unique(abbrevs), exclude)
  genera <- setdiff(unique(c(genera, sub(" .*", "", species))), exclude)

  # A genus that is also an English common name ("Gorilla", "Lynx") is only
  # set in italics on its own where the capital says it is the genus.
  common <- character()
  if (gbif) {
    common <- genera[.sp_lookup("gen", genera, cache, quiet) %in% "common"]
    common <- setdiff(common, forced)
  }

  # 3. Mark the names in each reference, and protect the words of `protect`.
  protect <- .sp_squish(protect)
  found <- character()
  doubtful <- data.frame(id = character(), word = character(), reason = character(),
                         line = integer(), stringsAsFactors = FALSE)
  report <- character()
  for (i in seq_along(items)) {
    id <- as.character(items[[i]]$id)
    taxa <- .sp_taxa_in_text(raw[[id]], species, abbrevs, genera, common,
                             setdiff(ambiguous, c(genera, exclude)), marks[[id]],
                             trinomials, unverified)
    found <- c(found, taxa$units$label)
    for (k in seq_along(taxa$doubtful)) {
      d <- .sp_explain_doubt(input, ext, id, taxa$doubtful[[k]],
                             names(taxa$doubtful)[k], raw[[id]])
      doubtful[nrow(doubtful) + 1L, ] <- list(id, taxa$doubtful[[k]],
                                              names(taxa$doubtful)[k], d$line)
      report <- c(report, d$text)
    }
    for (f in .sp_fields_of(items[[i]], fields)) {
      if (!is.character(items[[i]][[f]])) next
      s <- .sp_italicize_string(items[[i]][[f]], taxa)
      for (w in protect) {
        s <- .sp_sub_outside_italics(s, paste0("(?i)(?<![\\w-])", .sp_loose(w), "(?![\\w-])"),
                                     paste0('<span class="nocase">', w, "</span>"),
                                     skip_italic = FALSE)
      }
      # The whole field protected: the style does not touch its capitals.
      if (keep_case && nzchar(s)) s <- paste0('<span class="nocase">', s, "</span>")
      items[[i]][[f]] <- s
    }
  }

  json <- jsonlite::toJSON(items, auto_unbox = TRUE, pretty = TRUE,
                           null = "null", na = "null", digits = NA)
  json <- gsub("\\/", "/", json, fixed = TRUE)
  writeLines(enc2utf8(json), output, useBytes = TRUE)

  # Without a connection the result may be incomplete, which is worth saying
  # even when asked to be quiet.
  offline <- gbif && isTRUE(.sp_state$offline)
  if (offline) {
    n <- length(unique(sub("^[^:]*:", "", .sp_state$unresolved)))
    msg <- paste0(
      "No connection to GBIF/Wikipedia: ", n, " candidate words could not be ",
      "checked, so this version may be missing italics. Run again with a ",
      "connection; what has been checked stays in the cache",
      if (!is.null(cache)) paste0(" (", basename(cache), ")"), ".")
    if (isTRUE(getOption("knitr.in.progress"))) .sp_say(msg)
    warning(msg, call. = FALSE, immediate. = TRUE)
  }
  if (!quiet) {
    found <- sort(unique(found))
    if (length(found)) {
      .sp_say("Scientific names in italics (", length(found), "): ",
              paste(found, collapse = ", "))
    } else {
      .sp_say("No scientific names found in ", basename(input),
              if (offline) " (none could be checked without a connection)")
    }
    if (length(report)) {
      n <- length(report)
      .sp_say(if (n == 1L) "1 doubtful case, left in roman: the title alone cannot tell whether it is"
              else paste(n, "doubtful cases, left in roman: the title alone cannot tell whether they are"),
              " a genus. Decide by editing ", basename(input), " (the mark only affects ",
              "that reference, and a marked word is not reported again):\n\n",
              paste(report, collapse = "\n\n"), "\n")
    }
    if (told) .sp_say("Written: ", output)
  }
  invisible(structure(output, italicized = sort(unique(found)),
                      doubtful = doubtful, offline = offline))
}


# --- Reporting -------------------------------------------------------------

#' One doubtful case, told: where it is, the stretch of title it is in, and
#' what to write in the file for either answer.
#' @noRd
.sp_explain_doubt <- function(input, ext, id, word, reason, fields) {
  lines <- readLines(input, encoding = "UTF-8", warn = FALSE)
  start <- if (ext == "bib") {
    grep(paste0("@\\s*\\w+\\s*[{(]\\s*", .sp_re_escape(id), "\\s*,"), lines, perl = TRUE)[1]
  } else {
    grep(paste0('"id"\\s*:\\s*"?', .sp_re_escape(id), '"?\\s*[,}]'), lines, perl = TRUE)[1]
  }
  word_re <- paste0("\\b", word, "\\b")
  line <- NA_integer_
  if (!is.na(start)) {
    hits <- grep(word_re, lines, perl = TRUE)
    line <- hits[hits >= start][1]
    # In CSL-JSON the "id" may come after the title.
    if (ext == "json" && (is.na(line) || line - start > 30)) {
      line <- hits[which.min(abs(hits - start))]
    }
  }
  where <- if (is.na(line)) basename(input) else paste0(basename(input), ", line ", line)

  txt <- fields[grepl(word_re, fields, perl = TRUE)][1]
  pos <- regexpr(word_re, txt, perl = TRUE)
  from <- max(1, pos - 35)
  to <- min(nchar(txt), pos + nchar(word) + 35)
  context <- paste0(if (from > 1) "...", substr(txt, from, to), if (to < nchar(txt)) "...")

  # For a possible species, what is in doubt is the epithet.
  roman <- if (grepl(" ", word)) sub(".* ", "", word) else word
  if (ext == "bib") {
    it <- paste0("\\textit{", word, "}")
    up <- paste0("\\textup{", roman, "}")
  } else {
    it <- paste0("<i>", word, "</i>")
    up <- paste0('<span style=\\"font-style:normal;\\">', roman, "</span>")
  }
  what <- if (grepl(" ", word)) "a species" else "the genus"
  list(line = as.integer(line), text = paste0(
    "  * ", id, " (", where, "): \"", word, "\" ", reason, "\n",
    "      Title: ", context, "\n",
    "      If it is ", what, ", change ", word, " to  ", it, "\n",
    "      If it is not, ", strrep(" ", nchar(what) - 3), "change ", roman, " to  ", up
  ))
}

#' Messages. During a render knitr captures what a chunk says -- and with
#' include=FALSE nobody sees it -- so there it goes straight to stderr, which
#' does reach the render log.
#' @noRd
.sp_say <- function(...) {
  if (isTRUE(getOption("knitr.in.progress"))) {
    cat("[italicize_species] ", ..., "\n", sep = "", file = stderr())
  } else {
    message(...)
  }
}

#' @noRd
.sp_default_cache <- function() {
  file.path(tools::R_user_dir("easypaper", "cache"), "species_cache.rds")
}


# --- Reading the bibliography ----------------------------------------------

#' A .bib as CSL-JSON, converted by the same pandoc the render will use, so
#' the result is what pandoc itself would have made of the .bib. With
#' keep_case, every title is wrapped in double braces first, which is how
#' pandoc is told to leave its capitals alone.
#' @noRd
.sp_bib_to_csl <- function(path, keep_case = TRUE) {
  out <- tempfile(fileext = ".json")
  on.exit(unlink(out), add = TRUE)
  if (keep_case) {
    txt <- paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
    path <- tempfile(fileext = ".bib")
    on.exit(unlink(path), add = TRUE)
    writeLines(enc2utf8(.sp_protect_bib_titles(txt)), path, useBytes = TRUE)
  }
  pandoc <- .sp_find_pandoc()
  args <- c(pandoc$pre, shQuote(path.expand(path)), "-f", "biblatex", "-t", "csljson",
            "-o", shQuote(out))
  status <- suppressWarnings(system2(pandoc$cmd, args, stdout = TRUE, stderr = TRUE))
  if (!file.exists(out)) {
    stop("pandoc could not read ", basename(path), ":\n",
         paste(status, collapse = "\n"), call. = FALSE)
  }
  jsonlite::read_json(out, simplifyVector = FALSE)
}

#' The title fields pandoc lowercases when it reads a .bib.
#' @noRd
.sp_bib_title_fields <- paste0(
  "title|subtitle|titleaddon|shorttitle|booktitle|booksubtitle|booktitleaddon|",
  "maintitle|mainsubtitle|maintitleaddon|issuetitle|issuesubtitle|eventtitle|",
  "origtitle|series"
)

#' title = {Text} -> title = {{Text}};  title = "Text" -> title = {{Text}}
#' @noRd
.sp_protect_bib_titles <- function(txt) {
  field <- paste0("(?i)(?<![\\w-])(", .sp_bib_title_fields, ")(\\s*=\\s*)")
  txt <- gsub(paste0(field, "(\\{(?:[^{}]++|(?3))*+\\})"), "\\1\\2{\\3}", txt, perl = TRUE)
  gsub(paste0(field, '"((?:[^"\\\\]|\\\\.)*)"'), "\\1\\2{{\\3}}", txt, perl = TRUE)
}

#' pandoc: the one rmarkdown finds (RStudio's, or on the PATH), or the one
#' Quarto carries, called through `quarto pandoc`.
#' @noRd
.sp_find_pandoc <- function() {
  if (requireNamespace("rmarkdown", quietly = TRUE) && rmarkdown::pandoc_available()) {
    return(list(cmd = rmarkdown::pandoc_exec(), pre = character()))
  }
  if (nzchar(Sys.which("pandoc"))) {
    return(list(cmd = unname(Sys.which("pandoc")), pre = character()))
  }
  quarto <- c(Sys.getenv("QUARTO_PATH"),
              if (nzchar(Sys.getenv("QUARTO_BIN_PATH")))
                file.path(Sys.getenv("QUARTO_BIN_PATH"), "quarto"),
              unname(Sys.which("quarto")))
  quarto <- quarto[nzchar(quarto) & file.exists(quarto)]
  if (length(quarto)) return(list(cmd = quarto[1], pre = "pandoc"))
  stop("Cannot find pandoc, which reads the .bib. It comes with Quarto and ",
       "with RStudio: install either, or give a CSL-JSON bibliography instead.",
       call. = FALSE)
}

#' The title fields of every entry of a .bib, as written -- capitals included
#' -- with the LaTeX commands stripped, by key. And, as an attribute, the words
#' each entry marks by hand as italic or roman.
#' @noRd
.sp_bib_raw_fields <- function(path) {
  txt <- paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  head_re <- "@\\s*(\\w+)\\s*[{(]\\s*([^,\\s]+)\\s*,"
  m <- gregexpr(head_re, txt, perl = TRUE)[[1]]
  if (m[1] == -1) return(list())

  cs <- attr(m, "capture.start")
  cl <- attr(m, "capture.length")
  type <- tolower(substring(txt, cs[, 1], cs[, 1] + cl[, 1] - 1))
  key <- substring(txt, cs[, 2], cs[, 2] + cl[, 2] - 1)
  body_start <- m + attr(m, "match.length")
  body_end <- c(m[-1] - 1, nchar(txt))

  field_re <- paste0(
    "(?i)\\b(?:title|subtitle|titleaddon|shorttitle|booktitle|booksubtitle|",
    "maintitle|mainsubtitle|origtitle|series|eventtitle)",
    "\\s*=\\s*(?:(\\{(?:[^{}]++|(?1))*+\\})|\"((?:[^\"\\\\]|\\\\.)*)\")"
  )
  out <- list()
  marks <- list()
  for (i in seq_along(key)) {
    if (type[i] %in% c("comment", "string", "preamble")) next
    body <- substring(txt, body_start[i], body_end[i])
    vals <- regmatches(body, gregexpr(field_re, body, perl = TRUE))[[1]]
    vals <- sub("^[^=]*=\\s*", "", vals)
    out[[key[i]]] <- .sp_strip_latex(vals)
    marks[[key[i]]] <- list(
      italic = .sp_marked_words(vals, c("\\\\(?:textit|emph|textsl|mkbibemph|mkbibitalic)\\s*\\{([^{}]*)\\}",
                                        "\\{\\\\(?:it|em|itshape|sl)\\b\\s*([^{}]*)\\}")),
      roman = .sp_marked_words(vals, c("\\\\(?:textup|textrm|textnormal)\\s*\\{([^{}]*)\\}",
                                       "\\{\\\\(?:upshape|normalfont|rm)\\b\\s*([^{}]*)\\}"))
    )
  }
  attr(out, "marks") <- marks
  out
}

#' The words inside the marks `patterns` (group 1 of each).
#' @noRd
.sp_marked_words <- function(x, patterns) {
  x <- paste(x, collapse = " | ")
  inner <- unlist(lapply(patterns, function(re) {
    m <- regmatches(x, gregexpr(re, x, perl = TRUE))[[1]]
    sub(re, "\\1", m, perl = TRUE)
  }))
  unique(unlist(regmatches(inner, gregexpr("(*UCP)\\b\\p{L}[\\p{L}-]+\\b", inner, perl = TRUE))))
}

#' The fields of one reference to look into. The container is only a title
#' to read when it is a book -- the one a chapter or an entry belongs to. For
#' an article it is the journal, and a journal's name is left alone: several
#' are named after a genus (Oryx, Ibis, Helicobacter), and the style sets
#' them in italics already.
#' @noRd
.sp_fields_of <- function(item, fields) {
  book <- c("chapter", "entry", "entry-dictionary", "entry-encyclopedia")
  if (!isTRUE(item$type %in% book)) {
    fields <- setdiff(fields, c("container-title", "container-title-short"))
  }
  intersect(fields, names(item))
}

#' @noRd
.sp_strip_latex <- function(x) {
  cmds <- paste0("textit|emph|textbf|textsc|textup|textrm|textsl|textnormal|mkbibemph|",
                 "mkbibitalic|itshape|upshape|normalfont|it|em|bf|sl|sc|rm|nocase")
  x <- gsub(paste0("\\\\(", cmds, ")\\b\\s*"), "", x, perl = TRUE)
  x <- gsub("[{}\"]", "", x)
  gsub("~", " ", x, fixed = TRUE)
}

#' @noRd
.sp_squish <- function(x) trimws(gsub("\\s+", " ", as.character(x)))


# --- Candidates ------------------------------------------------------------

#' Words that are never a genus or an epithet: they save a lookup each.
#' @noRd
.sp_stop_genus <- c(
  "The", "This", "That", "These", "Those", "Their", "There", "When", "Where",
  "What", "Which", "While", "With", "From", "Into", "Over", "Under", "About",
  "After", "Before", "Between", "Among", "Using", "Does", "How", "Why", "New",
  "And", "For", "Not", "Are", "Can", "Our", "Its", "His", "Her", "One", "Two",
  "Los", "Las", "Del", "Una", "Uno", "Unos", "Unas", "Para", "Por", "Con",
  "Sin", "Sobre", "Entre", "Hacia", "Desde", "Como", "Este", "Esta", "Estos",
  "Estas", "Les", "Des", "Une", "Dans", "Pour", "Sur", "Avec", "Der", "Die",
  "Das", "Und", "Dos", "Nos", "Nas", "Uma", "Com", "Pela", "Pelo",
  # Ranks: some of them are genera in GBIF too
  "Genus", "Genera", "Species", "Family", "Order", "Class", "Kingdom",
  "Phylum", "Tribe", "Especie", "Especies", "Familia", "Orden", "Clase",
  "Reino", "Genre", "Gattung", "Art"
)

#' @noRd
.sp_stop_epithet <- c(
  "and", "the", "for", "from", "with", "into", "over", "under", "about",
  "after", "before", "between", "among", "using", "are", "was", "were", "has",
  "have", "had", "its", "their", "not", "but", "can", "may", "that", "this",
  "than", "then", "via", "per", "del", "los", "las", "una", "uno", "para",
  "por", "con", "sin", "sobre", "entre", "como", "que", "des", "les", "une",
  "dans", "pour", "sur", "avec", "und", "der", "die", "das", "dos",
  "nos", "nas", "uma", "com", "pela", "pelo", "species", "genus", "spp", "sp",
  "subsp", "ssp", "var", "cv", "sensu", "lato", "stricto"
)

#' "Genus epithet": a capitalised word and a lowercase one.
#' @noRd
.sp_binomial_candidates <- function(txt) {
  txt <- paste(txt, collapse = " | ")
  re <- "(*UCP)(?=\\b(\\p{Lu}\\p{Ll}{2,})\\s+(\\p{Ll}[\\p{Ll}-]{2,})\\b)"
  m <- gregexpr(re, txt, perl = TRUE)[[1]]
  if (m[1] == -1) return(character())
  cs <- attr(m, "capture.start")
  cl <- attr(m, "capture.length")
  g <- substring(txt, cs[, 1], cs[, 1] + cl[, 1] - 1)
  e <- substring(txt, cs[, 2], cs[, 2] + cl[, 2] - 1)
  keep <- !(g %in% .sp_stop_genus) & !(e %in% .sp_stop_epithet)
  unique(paste(g[keep], e[keep]))
}

#' "Q. suber" -- and not the tail of an acronym, "U.S.A. data".
#' @noRd
.sp_abbrev_candidates <- function(txt) {
  txt <- paste(txt, collapse = " | ")
  re <- "(*UCP)(?<![\\w.])(\\p{Lu})\\.\\s*(\\p{Ll}[\\p{Ll}-]{2,})\\b"
  m <- regmatches(txt, gregexpr(re, txt, perl = TRUE))[[1]]
  ep <- sub("^\\p{Lu}\\.\\s*", "", m, perl = TRUE)
  keep <- !(ep %in% .sp_stop_epithet)
  unique(paste0(substr(m[keep], 1, 1), ". ", ep[keep]))
}

#' A genus followed by "sp.", "spp." or "species", or preceded by "genus".
#' @noRd
.sp_genus_sp_candidates <- function(txt) {
  txt <- paste(txt, collapse = " | ")
  re <- paste0("(*UCP)\\b\\p{Lu}\\p{Ll}{2,}(?=\\s+(?:spp?\\.|(?i:species)\\b))|",
               "(?i:\\b(?:genus|genera|g\u00e9nero|g\u00e9neros|genre|gattung)\\s+)",
               "\\K\\p{Lu}\\p{Ll}{2,}\\b")
  g <- regmatches(txt, gregexpr(re, txt, perl = TRUE))[[1]]
  unique(setdiff(g, .sp_stop_genus))
}

#' "Helicobacter Pylori" -> "Helicobacter pylori", when the genus is known.
#' @noRd
.sp_cap_epithet_candidates <- function(txt, genera) {
  txt <- paste(txt, collapse = " | ")
  re <- "(*UCP)(?=\\b(\\p{Lu}\\p{Ll}{2,})\\s+(\\p{Lu}\\p{Ll}{2,})\\b)"
  m <- gregexpr(re, txt, perl = TRUE)[[1]]
  if (m[1] == -1) return(character())
  cs <- attr(m, "capture.start")
  cl <- attr(m, "capture.length")
  g <- substring(txt, cs[, 1], cs[, 1] + cl[, 1] - 1)
  e <- tolower(substring(txt, cs[, 2], cs[, 2] + cl[, 2] - 1))
  keep <- g %in% genera & !(e %in% .sp_stop_epithet)
  unique(paste(g[keep], e[keep]))
}

#' "Epilachna sparsa orientalis": a known species and one more lowercase word.
#' @noRd
.sp_trinomial_candidates <- function(txt, species) {
  txt <- paste(txt, collapse = " | ")
  out <- character()
  for (sp in species) {
    re <- paste0("(*UCP)\\b", .sp_loose(sp), "\\s+(\\p{Ll}[\\p{Ll}-]{2,})\\b")
    m <- regmatches(txt, gregexpr(re, txt, perl = TRUE))[[1]]
    third <- sub(".*\\s", "", m)
    out <- c(out, paste(sp, third[!(third %in% .sp_stop_epithet)]))
  }
  unique(out)
}

#' Does it look like a Latin epithet? It keeps the word after a species from
#' passing for a subspecies ("Helicobacter pylori infection") and a word that
#' happens to be an epithet somewhere from making a binomial ("Tribolium
#' sibling species").
#' @noRd
.sp_latin_like <- function(x) {
  english <- c("virus", "larvae", "larva", "pupae", "data", "media", "area", "focus",
               "status", "genus", "fungus", "bacteria", "criteria", "series",
               "analysis", "basis", "crisis", "thesis", "synthesis", "genesis",
               "stimulus", "nucleus", "consensus", "census", "corpus", "apparatus",
               "complex", "index", "cortex", "apex", "matrix", "helix", "appendix",
               "means", "lens", "species", "this", "axis", "medium", "spectrum",
               "under", "after", "other", "over", "water", "cancer", "layer",
               "border", "never", "either", "rather", "further", "however", "per")
  grepl("(a|ae|us|um|is|i|pes|ex|ix|ens|ans|er|color|minor|major)$", x) &
    !(tolower(x) %in% english)
}

#' Capitalised words that could be a genus on its own.
#' @noRd
.sp_capitalized_words <- function(txt) {
  txt <- paste(txt, collapse = " | ")
  w <- regmatches(txt, gregexpr("(*UCP)(?<![\\w.-])\\p{Lu}\\p{Ll}{2,}(?![\\w.-])",
                                txt, perl = TRUE))[[1]]
  unique(setdiff(w, .sp_stop_genus))
}

#' @noRd
.sp_binomial <- function(x) {
  x <- .sp_squish(x)
  vapply(strsplit(x, " "), function(w) paste(w[1:min(2, length(w))], collapse = " "), "")
}


# --- GBIF and Wikipedia ----------------------------------------------------

.sp_gbif_backbone <- "d7dddbf4-2cf0-4f39-9b2a-bb099caae36c"
.sp_state <- new.env()

#' Look words up in GBIF or Wikipedia, through the cache, and return one
#' answer per word. The kinds of question:
#'   "sp"   is "Genus epithet" a species in GBIF?
#'   "ssp"  is "Genus epithet epithet" a subspecies in GBIF?
#'   "gen"  is it a genus in GBIF? ("common" when it is also an English
#'          common name)
#'   "ep"   is it the epithet of some species in GBIF?
#'   "wp"   is its Wikipedia page about a genus? ("ambig": a disambiguation
#'          page; "missing": no page at all)
#'   "wpt"  are all the meanings of that disambiguation page living things?
#'   "auth" the authority of "Genus epithet" in GBIF ("Linnaeus, 1761"); ""
#'          when GBIF gives none
#' What could not be asked is not stored, so it is asked again next time.
#' Each kind of question is a lookup of its own, so the service is named once
#' a run -- once a call, inside a render -- not once a question.
#' @noRd
.sp_lookup <- function(type, x, cache, quiet) {
  if (!length(x)) return(character())
  keys <- paste0(type, ":", x)
  store <- if (!is.null(cache) && file.exists(cache)) readRDS(cache) else character()
  todo <- setdiff(unique(keys), names(store))

  if (length(todo) && !isTRUE(.sp_state$offline)) {
    service <- if (type %in% c("wp", "wpt")) "Wikipedia" else "GBIF"
    if (!quiet && !service %in% c(.sp_state$asked, .ep$said)) {
      .sp_say("Looking up new names in ", service, "...")
    }
    .sp_state$asked <- union(.sp_state$asked, service)
    if (!is.null(.ep$root)) .ep$said <- union(.ep$said, service)
    words <- sub("^[^:]*:", "", todo)
    res <- if (type == "wp") {
      unlist(lapply(split(words, ceiling(seq_along(words) / 50)), .sp_wiki_query))
    } else if (type == "wpt") {
      vapply(words, .sp_wiki_all_taxa, "")
    } else {
      vapply(words, function(w) .sp_gbif_query(type, w), "")
    }
    got <- !is.na(res)
    store[todo[got]] <- res[got]
    if (!all(got)) .sp_state$offline <- TRUE
    if (!is.null(cache) && any(got)) {
      dir.create(dirname(cache), recursive = TRUE, showWarnings = FALSE)
      try(saveRDS(store, cache), silent = TRUE)
    }
  }
  .sp_state$unresolved <- union(.sp_state$unresolved, setdiff(keys, names(store)))
  unname(store[keys])
}

#' "yes" or "no" from GBIF, NA without a connection. Names are compared
#' without diacritics: GBIF writes "Kalanchoe" where a title has "Kalancho\u00eb".
#' @noRd
.sp_gbif_query <- function(type, name) {
  if (isTRUE(.sp_state$offline)) return(NA_character_)
  q <- utils::URLencode(name, reserved = TRUE)
  url <- switch(type,
    sp = , ssp = , auth = paste0("https://api.gbif.org/v1/species/match?strict=true&name=", q),
    gen = paste0("https://api.gbif.org/v1/species/search?rank=GENUS&limit=50",
                 "&datasetKey=", .sp_gbif_backbone, "&q=", q),
    ep = paste0("https://api.gbif.org/v1/species/search?rank=SPECIES&limit=100",
                "&datasetKey=", .sp_gbif_backbone, "&q=", q)
  )
  res <- .sp_fetch_json(url)
  if (is.null(res)) {
    .sp_state$offline <- TRUE
    return(NA_character_)
  }
  if (type == "auth") {
    # "Formica rufa Linnaeus, 1761" less "Formica rufa".
    if (!identical(res$matchType, "EXACT") || !is.character(res$scientificName) ||
        !is.character(res$canonicalName)) return("")
    return(trimws(sub(res$canonicalName, "", res$scientificName, fixed = TRUE)))
  }
  ok <- switch(type,
    sp = identical(res$matchType, "EXACT") &&
      isTRUE(res$rank %in% c("SPECIES", "SUBSPECIES", "VARIETY", "FORM")) &&
      identical(.sp_fold(.sp_binomial(res$canonicalName)), .sp_fold(name)),
    ssp = identical(res$matchType, "EXACT") &&
      isTRUE(res$rank %in% c("SUBSPECIES", "VARIETY", "FORM")) &&
      identical(.sp_fold(res$canonicalName), .sp_fold(name)),
    gen = .sp_fold(name) %in% .sp_fold(res$results$canonicalName),
    ep = any(endsWith(.sp_fold(res$results$canonicalName), paste0(" ", .sp_fold(name))))
  )
  if (!isTRUE(ok)) return("no")
  if (type == "gen") {
    # Is the genus also its own English common name? GBIF's vernacular names
    # say so: "gorilla", "bison", "eucalyptus".
    hits <- res$results[.sp_fold(res$results$canonicalName) %in% .sp_fold(name), ]
    en <- unlist(lapply(hits$vernacularNames, function(v) {
      if (is.data.frame(v) && all(c("vernacularName", "language") %in% names(v))) {
        tolower(v$vernacularName[v$language %in% c("eng", "en")])
      }
    }))
    if (any(en %in% tolower(paste0(name, c("", "s", "es"))))) return("common")
  }
  "yes"
}

#' "yes", "no", "ambig" (a disambiguation page) or "missing" (no page) for up
#' to 50 words at once; NA without a connection. A word is a genus when its
#' page -- after redirects, "Pinus" -> "Pine" -- speaks of one: "Genus of
#' bacteria", against "Country in East Asia". A monotypic genus redirects to
#' its species, whose page then starts with the genus ("Ginkgo" -> "Ginkgo
#' biloba"); a page on another species with that epithet does not ("Faba" ->
#' "Vicia faba").
#' @noRd
.sp_wiki_query <- function(words) {
  out <- rep(NA_character_, length(words))
  if (isTRUE(.sp_state$offline)) return(out)
  url <- paste0("https://en.wikipedia.org/w/api.php?action=query&format=json",
                "&formatversion=2&prop=description%7Cpageprops",
                "&ppprop=disambiguation&redirects=1&titles=",
                utils::URLencode(paste(words, collapse = "|"), reserved = TRUE))
  res <- .sp_fetch_json(url, simplifyVector = FALSE)$query
  if (is.null(res)) {
    .sp_state$offline <- TRUE
    return(out)
  }
  final <- words
  for (step in c(res$normalized, res$redirects)) {
    final[final == step$from] <- step$to
  }
  titles <- vapply(res$pages, function(p) p$title, "")
  ambig <- vapply(res$pages, function(p) !is.null(p$pageprops$disambiguation), TRUE)
  missing <- vapply(res$pages, function(p) isTRUE(p$missing), TRUE)
  genus <- vapply(res$pages, function(p) {
    d <- .sp_or(p$description, "")
    is.null(p$pageprops$disambiguation) &&
      (grepl("\\b(genus|genera) of\\b|\\bin the genus\\b", d, ignore.case = TRUE) ||
         (grepl("\\bspecies of\\b", d, ignore.case = TRUE) &&
            sub(" .*", "", p$title) %in% words))
  }, TRUE)
  ifelse(final %in% titles[genus], "yes",
         ifelse(final %in% titles[ambig], "ambig",
                ifelse(final %in% titles[missing], "missing", "no")))
}

#' Are all the meanings of a disambiguation page, the "Name (something)"
#' links, living things? "yes" for "Tribolium" (beetle, plant), "no" for
#' "Iris" (plant, anatomy, mythology...), NA without a connection.
#' @noRd
.sp_wiki_all_taxa <- function(t) {
  if (isTRUE(.sp_state$offline)) return(NA_character_)
  taxa <- paste0("genus|plant|tree|shrub|grass|flower|alga|algae|moss|fern|fungus|",
                 "bacterium|bacteria|archaeon|protist|beetle|moth|butterfly|fly|",
                 "wasp|bee|ant|insect|bug|spider|mite|tick|crustacean|mollusc|",
                 "mollusk|snail|gastropod|bivalve|cephalopod|worm|nematode|coral|",
                 "sponge|fish|shark|bird|mammal|bat|rodent|frog|toad|amphibian|",
                 "lizard|snake|reptile|turtle|dinosaur|animal|organism|taxon")
  url <- paste0("https://en.wikipedia.org/w/api.php?action=query&format=json",
                "&formatversion=2&prop=links&plnamespace=0&pllimit=500&redirects=1&titles=",
                utils::URLencode(t, reserved = TRUE))
  res <- .sp_fetch_json(url, simplifyVector = FALSE)
  if (is.null(res)) {
    .sp_state$offline <- TRUE
    return(NA_character_)
  }
  links <- vapply(.sp_or(res$query$pages[[1]]$links, list()), function(l) l$title, "")
  kinds <- sub(".*\\((.*)\\)$", "\\1",
               links[startsWith(links, paste0(t, " (")) & endsWith(links, ")")])
  ok <- length(kinds) > 0 &&
    all(grepl(paste0("\\b(", taxa, ")\\b"), kinds, ignore.case = TRUE))
  if (ok) "yes" else "no"
}

#' Download and parse a JSON, retrying after a passing failure -- Wikipedia
#' and GBIF both turn a burst of requests away for a while. NULL when it
#' cannot be had. The option easypaper.species_offline = TRUE makes every
#' request fail at once: the tests use it so they never touch the network.
#' @noRd
.sp_fetch_json <- function(url, ..., tries = 4) {
  if (isTRUE(getOption("easypaper.species_offline"))) return(NULL)
  agent <- "easypaper (https://github.com/danielsangarci/easypaper)"
  for (k in seq_len(tries)) {
    res <- tryCatch({
      con <- url(url, headers = c("User-Agent" = agent))
      on.exit(close(con))
      jsonlite::fromJSON(paste(suppressWarnings(readLines(con, warn = FALSE,
                                                          encoding = "UTF-8")),
                               collapse = "\n"), ...)
    }, error = function(e) NULL)
    if (!is.null(res)) return(res)
    if (k < tries) Sys.sleep(2^(k - 1))
  }
  NULL
}

#' Lowercase, without diacritics, for comparing names.
#' @noRd
.sp_fold <- function(x) {
  x <- iconv(as.character(x), "UTF-8", "ASCII//TRANSLIT", sub = "")
  gsub("[^a-z -]", "", tolower(x))
}

#' @noRd
.sp_or <- function(a, b) if (is.null(a)) b else a

#' @noRd
.sp_re_escape <- function(x) gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", x)


# --- Marking ---------------------------------------------------------------

.sp_rank_re <- "(?:subsp\\.|ssp\\.|var\\.|f\\.|forma|morpha|cv\\.)"

#' Which names one reference contains, as written: a table of "units" to mark,
#' longest first; the doubtful cases; and the taxonomic vocabulary of the
#' reference, used to undo italics the bibliography already had.
#' @noRd
.sp_taxa_in_text <- function(fields, species, abbrevs, genera, common = character(),
                             ambiguous = character(), marks = list(),
                             trinomials = character(), unverified = character()) {
  txt <- paste(fields, collapse = " | ")
  units <- data.frame(label = character(), pattern = character(),
                      replacement = character(), stringsAsFactors = FALSE)
  vocab <- character()
  rest <- fields  # the text without its species, to find a genus on its own
  add <- function(label, pattern, replacement) {
    units[nrow(units) + 1, ] <<- list(label, paste0("(*UCP)", pattern), replacement)
  }

  # Subspecies with no rank ("Epilachna sparsa orientalis").
  for (h in trinomials) {
    detect <- paste0("(*UCP)(?<![\\w.])", .sp_loose(h), "\\b")
    if (!grepl(detect, txt, perl = TRUE)) next
    add(h, paste0("(?i)(?<![\\w.])", .sp_loose(h), "\\b"), .sp_tag(h))
    vocab <- c(vocab, strsplit(h, " ")[[1]])
  }
  # Every species, whole ("Quercus suber") and abbreviated ("Q. suber").
  heads <- unique(c(species,
                    paste0(substr(species, 1, 1), ". ", sub(".* ", "", species)),
                    abbrevs))
  for (h in heads) {
    g <- sub(" .*", "", h)
    e <- sub(".* ", "", h)
    detect <- paste0("(*UCP)(?<![\\w.])", .sp_loose(g), "\\s", if (grepl("\\.$", g)) "*" else "+",
                     "(?i:", e, ")\\b")
    if (!grepl(detect, txt, perl = TRUE)) next

    # With a rank: "Quercus ilex subsp. ballota", the rank in roman.
    re3 <- paste0(detect, "\\s+(", .sp_rank_re, ")\\s+(\\p{Ll}[\\p{Ll}-]{2,})\\b")
    for (m in regmatches(txt, gregexpr(re3, txt, perl = TRUE))[[1]]) {
      parts <- regmatches(m, regexec(paste0("\\s+(", .sp_rank_re, ")\\s+([\\p{Ll}-]+)$"),
                                     m, perl = TRUE))[[1]]
      add(paste(h, parts[2], parts[3]),
          paste0("(?i)(?<![\\w.])", .sp_loose(h), "\\s+", .sp_loose(parts[2]), "\\s+",
                 parts[3], "\\b"),
          paste0(.sp_tag(h), ' <span class="nocase">', parts[2], "</span> ",
                 .sp_tag(parts[3])))
      vocab <- c(vocab, parts[2], parts[3])
    }
    rest <- gsub(detect, " ", rest, perl = TRUE)
    add(h, paste0("(?i)(?<![\\w.])", .sp_loose(h), "\\b"), .sp_tag(h))
    vocab <- c(vocab, g, e)
  }

  doubtful <- character()
  for (sp in unverified) {
    if (!grepl(paste0("(*UCP)\\b", .sp_loose(sp), "\\b"), txt, perl = TRUE)) next
    if (any(strsplit(sp, " ")[[1]] %in% c(marks$italic, marks$roman))) next
    doubtful <- c(doubtful, structure(sp, names = "looks like a species, but GBIF does not list it"))
  }
  # A genus on its own ("Pinus forests", "Quercus spp.").
  for (g in c(genera, ambiguous)) {
    if (!any(grepl(paste0("(*UCP)\\b", g, "\\b"), rest, perl = TRUE))) next
    if (g %in% marks$roman) next
    # A classification in brackets after a species ("Encephalitozoon cuniculi
    # (Microspora)", "(Hymenoptera: Braconidae)") names a higher taxon that
    # happens to share the genus's name.
    if (nrow(units) > 0 && !(g %in% marks$italic) &&
        !any(grepl(paste0("(*UCP)(?<!\\(\\s|\\()\\b", g, "\\b"), rest, perl = TRUE))) next
    if (any(grepl(paste0("(*UCP)\\b", g, "\\s+spp?\\."), rest, perl = TRUE))) {
      add(paste(g, "spp."), paste0("(?i)\\b", g, "\\s+(spp?\\.)"),
          paste0(.sp_tag(g), ' <span class="nocase">\\1</span>'))
    }
    # A common name, or a word with several meanings: in italics only when
    # its use as a genus is clear; reported otherwise.
    if (!(g %in% marks$italic)) {
      if (g %in% ambiguous && !.sp_genus_usage_clear(g, rest, cue_only = TRUE)) {
        doubtful <- c(doubtful, structure(g, names = "has several meanings"))
        next
      }
      if (g %in% common && !.sp_genus_usage_clear(g, rest, genera)) {
        doubtful <- c(doubtful, structure(g, names = "is also an English common name"))
        next
      }
    }
    add(g, paste0("(?i)\\b", g, "\\b"), .sp_tag(g))
    vocab <- c(vocab, g)
  }
  units <- units[!duplicated(units$pattern), ]
  units <- units[order(-nchar(units$label)), ]
  units$label <- sub(" spp\\.$", "", units$label)
  list(units = units, doubtful = doubtful,
       vocab = unique(c(vocab, "sp.", "spp.", "subsp.", "ssp.", "var.", "f.", "cv.")))
}

#' Is `g` plainly used as a genus, not as a common name? Yes when followed by
#' "sp."/"spp."/"species" or preceded by "genus", or capitalised halfway
#' through a title where only the first word is -- right after a lowercase
#' word. After the start, a colon or a bracket the capital is compulsory, and
#' after another capital it belongs to a common name written the way English
#' writes a bird's ("Crested Caracara", "Eurasian Lynx"): neither says anything.
#' @noRd
.sp_genus_usage_clear <- function(g, fields, genera = g, cue_only = FALSE) {
  cue <- paste0("(*UCP)\\b", g, "\\s+(?:spp?\\.|(?i:species)\\b)|",
                "(?i:\\b(?:genus|g\u00e9nero|genre|gattung)\\s+)", g, "\\b")
  if (any(grepl(cue, fields, perl = TRUE))) return(TRUE)
  if (cue_only) return(FALSE)
  for (f in fields) {
    if (.sp_is_title_case(f, ignore = genera)) next
    before <- regmatches(f, gregexpr(paste0("(*UCP)\\S+(?=\\s+", g, "\\b)"),
                                     f, perl = TRUE))[[1]]
    if (any(grepl("^\\p{Ll}[\\p{L}-]*$", before, perl = TRUE))) return(TRUE)
  }
  FALSE
}

#' Is the title in title case? Nearly every word capitalised, leaving out the
#' first, the function words and the genera in `ignore`.
#' @noRd
.sp_is_title_case <- function(x, ignore = character()) {
  w <- regmatches(x, gregexpr("(*UCP)\\b\\p{L}{3,}\\b", x, perl = TRUE))[[1]][-1]
  w <- w[!(tolower(w) %in% c(.sp_stop_epithet, tolower(.sp_stop_genus))) & !(w %in% ignore)]
  if (!length(w)) return(TRUE)
  mean(grepl("^\\p{Lu}", w, perl = TRUE)) >= 0.75
}

#' "Q. suber" -> "Q\\.\\s*suber"; "Pinus halepensis" -> "Pinus\\s+halepensis"
#' @noRd
.sp_loose <- function(x) {
  x <- gsub(".", "\\.", .sp_squish(x), fixed = TRUE)
  x <- gsub("\\. ", "\\.\\s*", x, fixed = TRUE)
  gsub(" ", "\\s+", x, fixed = TRUE)
}

#' @noRd
.sp_tag <- function(x) paste0('<i><span class="nocase">', x, "</span></i>")

#' @noRd
.sp_italicize_string <- function(s, taxa) {
  s <- .sp_unwrap_existing(s, taxa$vocab)
  for (k in seq_len(nrow(taxa$units))) {
    s <- .sp_sub_outside_italics(s, taxa$units$pattern[k], taxa$units$replacement[k])
  }
  s
}

#' Take off the italics the bibliography already put around a name
#' (<i>Pinus</i> <i>halepensis</i>), to put them back right, with the capitals
#' protected. Every other italic ("in vitro") is left as it is.
#' @noRd
.sp_unwrap_existing <- function(s, vocab) {
  re <- "<i>((?:(?!</?i>).)*)</i>"
  m <- gregexpr(re, s, perl = TRUE)
  regmatches(s, m) <- lapply(regmatches(s, m), function(hits) {
    vapply(hits, function(h) {
      inner <- sub(re, "\\1", h, perl = TRUE)
      plain <- gsub("<[^>]+>", "", inner)
      words <- strsplit(.sp_squish(plain), " ")[[1]]
      if (length(words) && all(tolower(words) %in% tolower(vocab))) plain else h
    }, "", USE.NAMES = FALSE)
  })
  s
}

#' Apply `pattern` to the text outside the tags only and, with skip_italic,
#' outside whatever is already in italics.
#' @noRd
.sp_sub_outside_italics <- function(s, pattern, replacement, skip_italic = TRUE) {
  tags <- gregexpr("<[^>]+>", s, perl = TRUE)[[1]]
  if (tags[1] == -1) return(gsub(pattern, replacement, s, perl = TRUE))

  starts <- c(1, tags + attr(tags, "match.length"))
  ends <- c(tags - 1, nchar(s))
  tag_txt <- regmatches(s, list(tags))[[1]]
  depth <- 0
  out <- character()
  for (k in seq_along(starts)) {
    piece <- substring(s, starts[k], ends[k])
    if (depth == 0 || !skip_italic) piece <- gsub(pattern, replacement, piece, perl = TRUE)
    out <- c(out, piece)
    if (k <= length(tag_txt)) {
      t <- tag_txt[k]
      if (grepl("^<i\\b", t)) depth <- depth + 1
      if (grepl("^</i>", t)) depth <- max(0, depth - 1)
      out <- c(out, t)
    }
  }
  paste(out, collapse = "")
}
