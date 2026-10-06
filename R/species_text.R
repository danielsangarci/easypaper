# ---------------------------------------------------------------------------
# check_species_text() -- the scientific names of the text, the way journals
# ask for them: in italics, in full and with their authority the first time,
# with the genus abbreviated after that.
#
# It reads, it never writes: what it finds is reported with the file and the
# line, and the change is yours to make. Nothing calls it; it runs only when
# you do. The names are recognised with the machinery of italicize_species()
# -- GBIF, through the project's cache -- so a name looked up for the
# reference list is not looked up again.
# ---------------------------------------------------------------------------

#' Check the scientific names in the text
#'
#' Reads the manuscript -- every section, the captions of the figures and
#' tables, the supplement -- and reports, with the file and the line, every
#' scientific name not written the way journals ask.
#'
#' What they ask for:
#'
#' * **In italics**, the genus and the epithet, abbreviated or not, and a
#'   genus on its own (*Formica*); `sp.` and `spp.` in roman (*Formica* spp.).
#' * **In full the first time** (*Formica rufa*), and abbreviated after that
#'   (*F. rufa*) -- except at the start of a sentence, which never opens with
#'   an abbreviation, and when two genera of the text share the initial
#'   (*Formica*, *Fagus*), where *F.* would not say which. Headings and
#'   captions, which are read on their own, may give the name in full.
#' * **With its authority the first time** in the main text: *Formica rufa*
#'   Linnaeus, 1761, or (Linnaeus, 1761) for a species moved to another genus.
#'   The authority GBIF gives is suggested.
#'
#' The abstract, the main text and the supplement are read as three
#' documents, as a reader meets them: a name is given in full at its first
#' mention in each. The title is only checked for italics.
#'
#' Nothing is changed: whether a name in full there is a slip or a choice --
#' a sentence that compares two species of the same genus -- is yours to
#' say. Nothing calls it either: it runs when you call it, never in a render.
#'
#' @section How names are recognised:
#' A pair of words shaped like a genus and an epithet is a name when GBIF
#' lists the species, or -- when it is in italics somewhere in the text -- its
#' genus and its epithet. An abbreviation (*F. rufa*) is a name when it
#' abbreviates one of those, or GBIF knows its epithet. What GBIF said is kept
#' in `references/species_cache.rds`, the cache of [check_species()], so only
#' new names need a connection. Without one, the cache answers, a pair already
#' in italics is taken for a name, and a warning says what could not be
#' checked.
#'
#' @param authority `TRUE` (the default) asks for the authority at the first
#'   mention of each species in the main text. `FALSE` for a journal that does
#'   not want it, or gives the authorities in a table.
#' @param abbreviate `TRUE` (the default) asks for the genus abbreviated after
#'   the first mention. `FALSE` for a journal that writes names in full every
#'   time.
#' @param exclude Pairs of words that look like a name and are not one, or
#'   names to leave alone: `"Pinus pinea"`.
#' @param quiet `TRUE` returns what it found without printing it.
#' @param path The project, or any folder inside it. The working directory by
#'   default, which is the project root once its `.Rproj` is open.
#' @return A data frame, invisibly when printed, with one row per thing to
#'   look at: `file`, `line`, `name` as it is written, `problem`, and `fix`,
#'   what to write instead. The species found are its `species` attribute.
#' @seealso [check_species()], for the names in the reference list.
#' @export
#' @examples
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir, git = FALSE)
#' writeLines(c("Colonies of Formica rufa were sampled.", "",
#'              "*Formica rufa* builds mounds."),
#'            file.path(dir, "_sections", "02_introduction.qmd"))
#' # Offline: only the cache answers, and the pair in italics is taken for a
#' # name. Online, GBIF is asked once for each new name.
#' old <- options(easypaper.species_offline = TRUE)
#' suppressWarnings(check_species_text(path = dir))
#' options(old)
#' unlink(dir, recursive = TRUE)
check_species_text <- function(authority = TRUE, abbreviate = TRUE,
                               exclude = NULL, quiet = FALSE, path = ".") {
  .enter_project(path)
  .check_flag(authority, "authority")
  .check_flag(abbreviate, "abbreviate")
  .check_flag(quiet, "quiet")
  exclude <- .sp_squish(exclude)
  cache <- .species_cache()
  .sp_state$offline <- FALSE
  .sp_state$unresolved <- character()
  .sp_state$asked <- character()

  docs <- .species_docs()
  plain <- vapply(docs, `[[`, "", "plain")
  italic_txt <- unlist(lapply(docs, function(d) {
    if (nrow(d$italic)) substring(d$plain, d$italic[, 1], d$italic[, 2])
  }))

  # --- Which pairs of words are names --------------------------------------
  ans <- function(type, x) .sp_lookup(type, x, cache, quiet = TRUE)
  yes <- function(a) a %in% c("yes", "common")
  in_italics <- function(x) {
    vapply(x, function(n) any(grepl(paste0("(*UCP)(?<![\\p{L}-])", .sp_loose(n),
                                           "(?![\\p{L}-])"),
                                    italic_txt, perl = TRUE)), TRUE)
  }
  cands <- setdiff(.sp_binomial_candidates(plain), exclude)
  a <- ans("sp", cands)
  it <- in_italics(cands)
  gen <- sub(" .*", "", cands)
  ep  <- sub(".* ", "", cands)
  # In GBIF; or in italics and both halves in GBIF; or, with no answer at
  # all, in italics and Latin in shape: the author has said it is a name.
  rest <- !yes(a) & it & .sp_latin_like(ep)
  rest[rest] <- yes(ans("gen", gen[rest])) & yes(ans("ep", ep[rest])) |
    (is.na(a[rest]) & .sp_latin_like(ep[rest]))
  species <- sort(unique(cands[yes(a) | rest]))

  abbr <- setdiff(.sp_abbrev_candidates(plain), exclude)
  short <- paste0(substr(species, 1, 1), ". ", sub(".* ", "", species))
  lone <- setdiff(abbr, short)
  lone <- lone[yes(ans("ep", sub(".* ", "", lone))) |
                 (is.na(ans("ep", sub(".* ", "", lone))) & in_italics(lone))]

  genera <- unique(sub(" .*", "", species))
  sp_gen <- setdiff(.sp_genus_sp_candidates(plain), c(genera, exclude))
  genera <- c(genera, sp_gen[yes(ans("gen", sp_gen))])
  common <- genera[ans("gen", genera) %in% "common"]

  # --- What each document says about them ----------------------------------
  out <- list()
  add <- function(d, pos, name, problem, fix) {
    out[[length(out) + 1L]] <<- data.frame(
      file = d$file, line = .line_at(d$plain, pos), name = name,
      problem = problem, fix = fix, stringsAsFactors = FALSE)
  }
  auth_of <- function(sp) {
    if (!authority) return(sp)
    au <- ans("auth", sp)
    if (is.na(au) || !nzchar(au) || au == "no") paste(sp, "Author, year")
    else paste(sp, au)
  }

  for (scope in unique(vapply(docs, `[[`, "", "scope"))) {
    ds <- docs[vapply(docs, `[[`, "", "scope") == scope]
    occ <- .species_occurrences(ds, species, lone, genera)
    if (!nrow(occ)) next
    title_only <- scope == "title"
    here_gen <- unique(occ$genus[occ$kind %in% c("full", "genus")])
    shared <- function(g) {
      others <- setdiff(here_gen, g)
      any(substr(others, 1, 1) == substr(g, 1, 1))
    }

    # Italics, everywhere: the name in italics, "sp." and "spp." in roman.
    for (k in seq_len(nrow(occ))) {
      o <- occ[k, ]
      d <- ds[[o$doc]]
      if (o$kind == "genus" && o$genus %in% common) next
      if (!o$italic) {
        add(d, o$start, o$text, "not in italics", paste0("*", o$text, "*"))
      }
      if (o$kind == "genus" && o$sp_italic) {
        add(d, o$start, paste(o$text, o$sp), paste(o$sp, "in italics"),
            paste0("*", o$text, "* ", o$sp))
      }
    }
    if (title_only) next

    # First mention, authority, abbreviation: species by species.
    for (sp in unique(occ$species[occ$kind %in% c("full", "abbr")])) {
      o <- occ[occ$species %in% sp & occ$kind %in% c("full", "abbr"), ]
      o <- o[order(o$doc, o$start), ]
      g <- sub(" .*", "", sp)
      ab <- paste0(substr(sp, 1, 1), ". ", sub(".* ", "", sp))
      full_known <- sp %in% species
      first <- o[1, ]
      d <- ds[[first$doc]]
      if (first$kind == "abbr") {
        add(d, first$start, first$text, "first mention abbreviated",
            if (!full_known) "the genus in full"
            else if (scope == "main") auth_of(sp) else sp)
      } else if (authority && scope == "main" &&
                 !.has_authority(substr(d$plain, first$end + 1L,
                                        first$end + 120L))) {
        add(d, first$start, first$text, "first mention without its authority",
            auth_of(sp))
      }
      if (!abbreviate || nrow(o) < 2L) next
      for (k in 2:nrow(o)) {
        x <- o[k, ]
        d <- ds[[x$doc]]
        start <- .sentence_start(d, x$start)
        if (x$kind == "full") {
          if (start || x$standalone || shared(g)) next
          add(d, x$start, x$text, "in full after its first mention", ab)
        } else if (full_known && start) {
          add(d, x$start, x$text, "abbreviated at the start of a sentence", sp)
        } else if (full_known && shared(g)) {
          other <- setdiff(here_gen[substr(here_gen, 1, 1) == substr(g, 1, 1)], g)
          add(d, x$start, x$text,
              paste0(substr(g, 1, 1), ". could also be ",
                     paste(other, collapse = ", ")), sp)
        }
      }
    }
  }

  res <- if (length(out)) do.call(rbind, out) else
    data.frame(file = character(), line = integer(), name = character(),
               problem = character(), fix = character(),
               stringsAsFactors = FALSE)
  res <- unique(res)
  res <- res[order(match(res$file, unique(vapply(docs, `[[`, "", "file"))),
                   res$line), , drop = FALSE]
  rownames(res) <- NULL
  attr(res, "species") <- species

  if (isTRUE(.sp_state$offline)) {
    n <- length(unique(sub("^[^:]*:", "", .sp_state$unresolved)))
    warning("No connection to GBIF: ", n, " pairs of words could not be ",
            "checked, so a name may be missing from this report. Only the ",
            "cache and the italics of the text answered; run it again with a ",
            "connection.", call. = FALSE)
  }
  if (quiet) return(res)
  message(.species_text_report(res, species))
  invisible(res)
}

#' What it found, one thing to a line: where, the name as written, what is
#' wrong, and what to write.
#' @noRd
.species_text_report <- function(res, species) {
  if (!length(species)) return("Scientific names in the text: none found.")
  head <- sprintf("Scientific names in the text: %s", paste(species, collapse = ", "))
  if (!nrow(res)) return(paste0(head, "\n  Nothing to change."))
  where <- paste0(res$file, ":", res$line)
  lines <- sprintf("  %-*s  %-*s  %s -> %s", max(nchar(where)), where,
                   max(nchar(res$name)), res$name, res$problem, res$fix)
  paste(c(head, sprintf("%d thing%s to look at:", nrow(res),
                        if (nrow(res) == 1L) "" else "s"), lines),
        collapse = "\n")
}

# --- The text --------------------------------------------------------------

#' The documents to read, in order: the title, then every section file the
#' manuscript includes, each with its scope -- "title", "abstract", "main" or
#' "supplement" -- its prose, and the spans of it in italics.
#' @noRd
.species_docs <- function() {
  master <- readLines(.master(), warn = FALSE, encoding = "UTF-8")
  docs <- list()

  # The title and the short title: their lines of the YAML, nothing else.
  ends <- which(trimws(master) == "---")
  yaml_end <- if (length(ends) >= 2L && ends[1] == 1L) ends[2] else 0L
  keep <- seq_along(master) <= yaml_end &
    grepl("^(title|short-title)\\s*:", master)
  if (any(keep)) {
    l <- master
    l[!keep] <- ""
    l[keep] <- .blank_prefix(l[keep], "^(title|short-title)\\s*:\\s*")
    docs[[1]] <- .species_doc("manuscript.qmd", l, "title")
  }

  files <- .section_files()
  abstract <- .section_block(master, "Abstract")
  abstract <- .p(trimws(gsub("^\\{\\{< *include +|>\\}\\}$", "",
    regmatches(abstract, regexpr("\\{\\{< *include +[^>]+? *>\\}\\}", abstract)))))
  suppl <- .suppl_files()
  for (f in files) {
    scope <- if (f %in% abstract) "abstract"
             else if (f %in% suppl) "supplement" else "main"
    l <- readLines(f, warn = FALSE, encoding = "UTF-8")
    if (scope == "abstract") l[.is_keywords_line(l)] <- ""
    rel <- substring(f, nchar(.p()) + 2L)
    docs[[length(docs) + 1L]] <- .species_doc(rel, l, scope)
  }
  docs
}

#' One document: its lines reduced to the prose a reader sees, at the same
#' positions -- whatever is not prose becomes spaces, so a position is still
#' a line and a column of the file.
#' @noRd
.species_doc <- function(file, l, scope) {
  l <- enc2utf8(l)
  # Code chunks are not prose, except the captions in their options.
  fence <- grepl("^\\s*```", l)
  inside <- (cumsum(fence) %% 2 == 1) | fence
  cap <- inside & grepl("^\\s*#\\|\\s*(fig|tbl)-cap\\s*:", l)
  l[inside & !cap] <- ""
  l[cap] <- .blank_prefix(l[cap], "^\\s*#\\|\\s*(fig|tbl)-cap\\s*:\\s*")
  heading <- grepl("^#{1,6}\\s", l)
  txt <- paste(l, collapse = "\n")
  for (re in c("(?s)<!--.*?-->",                 # comments
               "\\{\\{<.*?>\\}\\}",               # shortcodes
               "`[^`\n]*`",                       # inline code
               "https?://[^\\s)>\\]]+",           # addresses
               "\\]\\([^)\n]*\\)",                # link and image targets
               "\\{[#.][^}\n]*\\}",               # attributes
               # citations and cross-references
               "(?<![\\p{L}\\p{N}_\\\\])-?@[\\p{L}\\p{N}_][\\p{L}\\p{N}_:.#$%&+?<>~/-]*")) {
    txt <- .blank_out(txt, re)
  }
  italic <- .italic_spans(txt)
  # The plain text: the marks of the markup go, the words stay where they are.
  plain <- .blank_out(txt, "</?[A-Za-z][^>\n]*>")
  plain <- gsub("[*_#>\\\\]", " ", plain)
  list(file = file, scope = scope, txt = txt, plain = plain, italic = italic,
       caption = which(cap), heading = which(heading))
}

#' The matches of `re`, turned into spaces; the newlines stay.
#' @noRd
.blank_out <- function(txt, re) {
  m <- gregexpr(re, txt, perl = TRUE)
  if (m[[1]][1] == -1) return(txt)
  regmatches(txt, m) <- list(gsub("[^\n]", " ", regmatches(txt, m)[[1]]))
  txt
}

#' The start of each line that matches `re`, turned into spaces.
#' @noRd
.blank_prefix <- function(l, re) {
  m <- regexpr(re, l, perl = TRUE)
  has <- m > 0
  l[has] <- paste0(strrep(" ", attr(m, "match.length")[has]),
                   substring(l[has], attr(m, "match.length")[has] + 1L))
  l
}

#' The spans in italics, as a two-column matrix of first and last character:
#' *one* and _one_, never **bold**, and <i>/<em>. Across a line break, not
#' across a paragraph.
#' @noRd
.italic_spans <- function(txt) {
  res <- c(paste0("(?<![*\\\\])\\*(?![*\\s])(?:[^*\n]|\n(?![ \t]*\n))+?",
                  "(?<![\\s*\\\\])\\*(?!\\*)"),
           paste0("(?<![\\p{L}\\p{N}_\\\\])_(?![_\\s])(?:[^_\n]|\n(?![ \t]*\n))+?",
                  "(?<![\\s_])_(?![\\p{L}\\p{N}_])"),
           "(?is)<(i|em)>.*?</\\1>")
  spans <- lapply(res, function(re) {
    m <- gregexpr(re, txt, perl = TRUE)[[1]]
    if (m[1] == -1) return(NULL)
    cbind(as.integer(m), as.integer(m) + attr(m, "match.length") - 1L)
  })
  s <- do.call(rbind, spans)
  if (is.null(s)) matrix(integer(), ncol = 2) else s
}

#' The line of a position.
#' @noRd
.line_at <- function(txt, pos) {
  vapply(pos, function(p) {
    lengths(regmatches(substr(txt, 1L, p), gregexpr("\n", substr(txt, 1L, p)))) + 1L
  }, integer(1))
}

#' Every mention of the names in some documents, in order: the species in
#' full ("full"), abbreviated ("abbr"), and a genus on its own ("genus").
#' `lone` are abbreviations of species never written in full.
#' @noRd
.species_occurrences <- function(ds, species, lone, genera) {
  rows <- list()
  for (i in seq_along(ds)) {
    d <- ds[[i]]
    taken <- integer()
    find <- function(re) {
      m <- gregexpr(re, d$plain, perl = TRUE)[[1]]
      if (m[1] == -1) return(NULL)
      cbind(as.integer(m), as.integer(m) + attr(m, "match.length") - 1L)
    }
    italic_at <- function(s, e) {
      any(d$italic[, 1] <= s & d$italic[, 2] >= e)
    }
    put <- function(m, kind, sp, g, sp_word = NA_character_, sp_italic = FALSE) {
      for (r in seq_len(nrow(m))) {
        s <- m[r, 1]; e <- m[r, 2]
        if (s %in% taken) next
        text <- gsub("\\s+", " ", substr(d$plain, s, e))
        ln <- .line_at(d$plain, s)
        rows[[length(rows) + 1L]] <<- data.frame(
          doc = i, start = s, end = e, kind = kind, species = sp, genus = g,
          text = text, italic = italic_at(s, e), sp = sp_word[min(r, length(sp_word))],
          sp_italic = sp_italic[min(r, length(sp_italic))],
          standalone = ln %in% c(d$caption, d$heading), stringsAsFactors = FALSE)
        taken <<- c(taken, s)
      }
    }
    for (sp in species) {
      g <- sub(" .*", "", sp); e <- sub(".* ", "", sp)
      m <- find(paste0("(*UCP)(?<![\\p{L}\\p{N}.-])", .sp_re_escape(g), "\\s+",
                       .sp_re_escape(e), "(?![\\p{L}\\p{N}-])"))
      if (!is.null(m)) put(m, "full", sp, g)
      m <- find(paste0("(*UCP)(?<![\\p{L}\\p{N}.])", substr(g, 1, 1), "\\.\\s*",
                       .sp_re_escape(e), "(?![\\p{L}\\p{N}-])"))
      if (!is.null(m)) put(m, "abbr", sp, g)
    }
    for (ab in lone) {
      m <- find(paste0("(*UCP)(?<![\\p{L}\\p{N}.])", substr(ab, 1, 1), "\\.\\s*",
                       .sp_re_escape(sub(".* ", "", ab)), "(?![\\p{L}\\p{N}-])"))
      if (!is.null(m)) put(m, "abbr", ab, NA_character_)
    }
    for (g in genera) {
      re <- paste0("(*UCP)(?<![\\p{L}\\p{N}.-])", .sp_re_escape(g),
                   "(?![\\p{L}\\p{N}-])")
      m <- find(re)
      if (is.null(m)) next
      m <- m[!m[, 1] %in% taken, , drop = FALSE]
      if (!nrow(m)) next
      # "Formica spp.": the genus in italics, "spp." in roman.
      after <- substring(d$plain, m[, 2] + 1L, m[, 2] + 8L)
      spw <- ifelse(grepl("^\\s+spp?\\.", after),
                    sub("^\\s+(spp?\\.).*$", "\\1", after), NA_character_)
      sp_it <- vapply(seq_len(nrow(m)), function(r) {
        if (is.na(spw[r])) return(FALSE)
        at <- m[r, 2] + regexpr("sp", after[r])
        any(d$italic[, 1] <= at & d$italic[, 2] >= at)
      }, TRUE)
      put(m, "genus", NA_character_, g, spw, sp_it)
    }
  }
  if (!length(rows)) {
    return(data.frame(doc = integer(), start = integer(), end = integer(),
                      kind = character(), species = character(),
                      genus = character(), text = character(),
                      italic = logical(), sp = character(),
                      sp_italic = logical(), standalone = logical(),
                      stringsAsFactors = FALSE))
  }
  out <- do.call(rbind, rows)
  out[order(out$doc, out$start), , drop = FALSE]
}

#' Does a sentence start at this position? After a full stop, at the start
#' of a paragraph, a heading or an item of a list -- but not after "e.g.",
#' "et al." or an initial, which end with a full stop and no sentence.
#' @noRd
.sentence_start <- function(d, pos) {
  b <- substr(d$plain, max(1L, pos - 300L), pos - 1L)
  if (grepl("(^|\\n[ \\t]*\\n)[\\s\"'(\\[\u201c\u2018]*$", b, perl = TRUE)) {
    return(TRUE)
  }
  line <- sub("^.*\\n", "", substr(d$txt, max(1L, pos - 300L), pos - 1L))
  if (grepl("^\\s*(#{1,6}|[-*+]|[0-9]+[.)])\\s+[*_\"'(\\[]*$", line, perl = TRUE)) {
    return(TRUE)
  }
  if (!grepl("[.!?][\"')\\]\u201d\u2019]*\\s+[\"'(\\[\u201c\u2018]*$", b, perl = TRUE)) {
    return(FALSE)
  }
  last <- sub("[\"')\\]\u201d\u2019]*$", "",
              regmatches(b, regexpr("\\S+(?=\\s+[\"'(\\[\u201c\u2018]*$)", b, perl = TRUE)))
  !(tolower(last) %in% c("e.g.", "i.e.", "cf.", "al.", "sp.", "spp.", "vs.",
                         "fig.", "figs.", "approx.", "ca.", "var.", "subsp.",
                         "ssp.", "no.", "nos.", "pp.", "p.", "etc.") |
      grepl("^\\p{Lu}\\.$", last, perl = TRUE))
}

#' Is what follows a name its authority? "Linnaeus, 1761", "L.",
#' "(Forel, 1874)", "de Geer" -- but not "(Hymenoptera: Formicidae)", which
#' is where the name belongs, nor "(red wood ant)".
#' @noRd
.has_authority <- function(after) {
  after <- sub("^\\s+", "", after)
  particle <- "(?:(?:d'|de |van |von |da |du |del |le |la |ter |zur )?\\p{Lu})"
  if (startsWith(after, "(")) {
    inner <- sub("^\\(([^)]{0,80})\\).*$", "\\1", after)
    if (identical(inner, after)) return(FALSE)
    if (grepl(paste0(":|idae\\b|inae\\b|aceae\\b|ales\\b|ptera\\b|formes\\b|",
                     "phyta\\b|mycota\\b|\\bfamily\\b|\\border\\b"),
              inner, ignore.case = TRUE, perl = TRUE)) {
      return(FALSE)
    }
    return(grepl(paste0("^\\s*", particle), inner, perl = TRUE))
  }
  grepl(paste0("(*UCP)^", particle, "[\\p{L}'\u2019-]*\\.?(?=[\\s,;)&]|$)"),
        after, perl = TRUE)
}
