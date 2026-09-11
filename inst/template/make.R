# ===========================================================================
# make.R - THE ONLY entry point of the project.
#
#   source("make.R")
#   render_docx("myrmecological-news")  # the .docx a journal asks for
#   render_pdf()                        # the .pdf for a preprint server
#   render_supplementary()              # the supplement, on its own
#   render_html()                       # working .html (or live preview())
#   export_code()                       # clean .R for the supplementary material
#   make_all()                          # the four above -- not the .html
#
#   make_submission("myrmecological-news")  # label = "MyrmecologicalNews" for the real thing
#   make_preprint()                     # the whole preprint deposit: signed
#                                       # .pdf, supplement, figures, data, code
#
# Quarto can also be called from the terminal (`quarto render`), but then you
# skip the citation checks and the licence synchronisation. To build for real,
# use these functions.
#
# Every argument -- journal, caption_style, suppl_figures, label,
# figure_format, blinded, snapshot -- is explained beside its command in run.R,
# and laid out in tables in the Get started guide:
#   https://danielsangarci.github.io/easypaper/articles/easypaper.html
# ===========================================================================

library(here)
library(quarto)
source(here("R/crossref_styles.R"))
source(here("R/submission.R"))
source(here("R/convert_data.R"))

MASTER    <- here("manuscript.qmd")
SECTIONS  <- here("_sections")
OUTPUT    <- here("output")          # = project: output-dir in _quarto.yml

# output/, figures/ and cache/ are in .gitignore, so they do not exist after a
# clone. They are created here so make_all() works on a freshly cloned copy of
# the template.
for (d in c("output", "figures", "cache")) {
  dir.create(here(d), recursive = TRUE, showWarnings = FALSE)
}

#' A path inside output/, with the folder created if it is not there.
#'
#' Everything a render produces lands flat in output/: the .docx, the .pdf,
#' the supplement, the code. One folder, because you open it to find a
#' document, not to navigate.
#'
#' The directory is created here, at the moment of writing, and not only when
#' make.R is sourced. output/ is regenerable and .gitignored, so it is absent
#' after a clone and the README calls deleting it safe -- and a render that
#' trusted a folder made at load time failed, in a session that was still
#' open, with a message about a temporary file rather than a missing folder.
#' @noRd
.out <- function(...) {
  p <- here("output", ...)
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  p
}

# --- Utilities -------------------------------------------------------------

#' CSL files available in references_styles/
list_journals <- function() {
  sub("\\.csl$", "", basename(list.files(here("references_styles"), "\\.csl$")))
}

#' Which journal to use: the one you asked for, or the project's own.
#'
#' The manuscript declares a `csl:` in its YAML, beside its title and its
#' authors, and that is where it says which journal it is going to. Naming
#' `journal` in a call overrides it, for that call only. `_quarto.yml` is read
#' as a fallback, which is where older projects declared it.
#'
#' The order is Quarto's own: the document beats the project.
#'
#' Before this they could disagree without saying so: a render from the RStudio
#' button used the .csl in _quarto.yml while make_submission() used a default
#' of its own, so the same project produced two different journals depending on
#' how you asked.
#' @noRd
.resolve_journal <- function(journal = NULL) {
  if (!is.null(journal) && nzchar(journal)) return(journal)
  csl <- tryCatch(rmarkdown::yaml_front_matter(MASTER)$csl,
                  error = function(e) NULL)
  if (is.null(csl) || !length(csl) || !nzchar(as.character(csl)[1])) {
    csl <- tryCatch(yaml::read_yaml(here("_quarto.yml"))$csl,
                    error = function(e) NULL)
  }
  if (is.null(csl) || !length(csl) || !nzchar(as.character(csl)[1])) {
    stop("No journal named, and neither ", basename(MASTER), " nor ",
         "_quarto.yml has a `csl:` line to take one from. Either add it to ",
         "the manuscript's YAML, or name one here. Available: ",
         paste(list_journals(), collapse = ", "), call. = FALSE)
  }
  sub("\\.csl$", "", basename(as.character(csl)[1]))
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
#' data/, run this before rendering.
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

TEMPLATE_AUTHORS <- c("Author1", "Author2")

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

#' The journal's name as its own .csl declares it.
#'
#' The argument you pass around is a file name -- "myrmecological-news" --
#' and the style itself carries the name a reader expects to see. Falls back
#' to the file name when the style has no title.
#' @noRd
.journal_name <- function(journal) {
  f <- here("references_styles", paste0(journal, ".csl"))
  if (!file.exists(f)) return(journal)
  x <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = " ")
  t <- regmatches(x, regexpr("<title>[^<]*</title>", x))
  if (!length(t)) return(journal)
  nm <- trimws(gsub("<[^>]+>", "", t[1]))
  if (nzchar(nm)) nm else journal
}

#' One name the way a reference writes it: "Ada Lovelace" -> "Lovelace, A."
#'
#' The last word is taken as the family name and the rest as given names.
#' That is right for most, and wrong for a particle somebody wants kept --
#' "van der Berg" comes out as "Berg, V. D.". Write such a name here the way
#' you want it read.
#' @noRd
.reference_name <- function(x) {
  parts <- strsplit(trimws(x), "[[:space:]]+")[[1]]
  parts <- parts[nzchar(parts)]
  if (length(parts) < 2L) return(trimws(x))
  initials <- paste0(substr(parts[-length(parts)], 1, 1), ".", collapse = " ")
  paste0(parts[length(parts)], ", ", initials)
}

#' The manuscript written out as a reference: authors, title, journal.
#'
#' It is what the supplement opens with, under its own title, so a file
#' downloaded on its own still says which paper it belongs to. Blinded, the
#' authors are left out and the reference is title and journal alone.
#' @noRd
.manuscript_reference <- function(journal, blinded = FALSE) {
  who <- if (blinded) character(0) else
    tryCatch(.author_names(), error = function(e) character(0))
  ttl <- rmarkdown::yaml_front_matter(MASTER)$title
  parts <- c(if (length(who))
               paste(vapply(who, .reference_name, character(1)), collapse = ", "),
             if (!is.null(ttl)) as.character(ttl)[1],
             .journal_name(journal))
  parts <- trimws(parts[nzchar(trimws(parts))])
  if (!length(parts)) return(NULL)
  # A part that already ends in a full stop does not get a second one: the
  # author list ends in an initial, "Turing, A.".
  ends <- grepl("[.]$", parts)
  parts[!ends] <- paste0(parts[!ends], ".")
  paste(parts, collapse = " ")
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

#' What is in data/ that the analysis never reads.
#'
#' data/ is not "my clean data", it is "what I am going to publish":
#' the compendium copies it whole and sync_metadata() describes every file in
#' it. A .csv from a path you abandoned travels to the repository and gets
#' listed in the metadata, and nothing tells you.
#'
#' It reports; it never removes. A file read through a path the code builds --
#' paste0("data/", species, ".csv"), a loop over list.files() -- is
#' invisible to any scan, so dropping the ones that look unused would sooner or
#' later publish a compendium with a hole in it. Shipping one file too many is
#' a nuisance; shipping one too few breaks the reproduction. Hence the asymmetry.
#'
#' @return TRUE when every file the code names exists.
check_data <- function(quiet = FALSE) {
  dir <- here("data")
  if (!dir.exists(dir)) return(invisible(TRUE))
  # metadata/ describes the data, it is not data: it reaches the deposit on its
  # own and no analysis reads it. Same for the folder's own README.
  present <- list.files(dir, recursive = TRUE)
  present <- present[!startsWith(present, "metadata/") & present != "README.md"]
  if (!length(present)) return(invisible(TRUE))

  # The same files the compendium publishes: the paper and the analysis code.
  src <- c(MASTER, .section_files(), here("R/setup.R"),
           list.files(here("R"), "^analysis.*[.]R$", full.names = TRUE))
  src <- src[file.exists(src)]
  txt <- unlist(lapply(src, readLines, warn = FALSE))
  hit <- unlist(regmatches(txt, gregexpr(
    "(?<![A-Za-z0-9_.-])data/[A-Za-z0-9_./-]+", txt, perl = TRUE)))
  read <- unique(sub("^data/", "", hit))
  read <- read[!startsWith(read, "metadata/")]

  missing <- setdiff(read, present)
  if (length(missing)) {
    warning("The analysis reads files that are not in data/: ",
            paste(missing, collapse = ", "), call. = FALSE, immediate. = TRUE)
  }
  # A shapefile is one dataset spread over half a dozen files, and the code
  # only ever names the .shp. Its companions are not unused: they are the same
  # file, and reporting them would train you to ignore this message.
  sidecar <- c("shx", "dbf", "prj", "cpg", "sbn", "sbx", "qix")
  shp <- tools::file_path_sans_ext(
    read[tolower(tools::file_ext(read)) == "shp"])
  unused <- setdiff(present, read)
  unused <- unused[!(tolower(tools::file_ext(unused)) %in% sidecar &
                       tools::file_path_sans_ext(unused) %in% shp)]
  if (length(unused) && !quiet) {
    message("Note: in data/ but never read by the analysis: ",
            paste(unused, collapse = ", "), "\n  They travel into the ",
            "compendium and into its metadata all the same. Move them out of ",
            "data/ if they are not part of the paper.")
  }
  invisible(!length(missing))
}

#' Read one of the deposit's metadata .csv files.
#'
#' dataspice writes its scaffold without a final newline, and read.csv warns
#' about that on every render until the file has been written back once. The
#' warning says nothing about the data, which reads correctly, so it is
#' muffled -- and only that one: any other warning the read raises still
#' reaches you. Your own data files are read elsewhere and are not touched by
#' this, because a malformed line in one of those is worth hearing about.
#' @noRd
.read_meta <- function(f, ...) {
  withCallingHandlers(
    utils::read.csv(f, ...),
    warning = function(w) {
      if (grepl("incomplete final line", conditionMessage(w), fixed = TRUE)) {
        invokeRestart("muffleWarning")
      }
    })
}

#' Fill in what the deposit's metadata can know by itself.
#'
#' dataspice describes the data deposit with four .csv files, and three of
#' their columns are already written down elsewhere in this project: the title
#' and the keywords in the YAML of the manuscript, the authors in the same
#' block that feeds the licences, and the variable names inside the data files.
#' Copying them by hand is how the deposit ends up disagreeing with the paper.
#'
#' It only ever ADDS. A cell you have filled is never touched and a variable
#' you have described is never rewritten, so this can run on every render
#' without eating your work. What no machine can guess -- units, descriptions,
#' the temporal and geographic coverage, the licence of the deposit -- is still
#' yours to write, with edit_attributes() and its friends. See
#' R/create_metadata.R.
sync_metadata <- function(quiet = FALSE) {
  if (!requireNamespace("dataspice", quietly = TRUE)) {
    if (!quiet) {
      message("dataspice is not installed, so the metadata of the deposit is ",
              "not being kept in step. install.packages(\"dataspice\")")
    }
    return(invisible(NA))
  }
  # create_spice() copies its templates with file.copy() and no overwrite, so
  # anything already filled in survives being called again.
  suppressMessages(dataspice::create_spice(dir = here("data")))
  md   <- here("data", "metadata")
  yml  <- rmarkdown::yaml_front_matter(MASTER)
  done <- character(0)

  # --- biblio: the title and the keywords are in the manuscript --------------
  f <- file.path(md, "biblio.csv")
  b <- .read_meta(f, colClasses = "character")
  if (!nrow(b)) b[1, ] <- NA_character_
  blank <- function(x) is.na(x) || !nzchar(trimws(x))
  put <- function(d, col, value) {
    if (col %in% names(d) && length(value) == 1L && nzchar(value) &&
        blank(d[[col]][1])) {
      d[[col]][1] <- value
      done <<- c(done, col)
    }
    d
  }
  b <- put(b, "title", if (is.null(yml$title)) "" else as.character(yml$title))
  b <- put(b, "keywords", paste(unlist(yml$keywords), collapse = ", "))
  utils::write.csv(b, f, row.names = FALSE, na = "")

  # --- creators: the authors of the paper are the creators of the data ------
  # dataspice keeps one `name` field, not a given/family pair: the name goes in
  # whole, exactly as the manuscript writes it.
  f  <- file.path(md, "creators.csv")
  cr <- .read_meta(f, colClasses = "character")
  who <- tryCatch(.author_names(), error = function(e) character(0))
  added <- 0L
  for (nm in who) {
    if (!"name" %in% names(cr)) break
    if (nrow(cr) && any(trimws(cr$name) == nm, na.rm = TRUE)) next
    row <- as.list(rep("", ncol(cr))); names(row) <- names(cr)
    row$name <- nm
    keep <- if (nrow(cr)) !apply(is.na(cr) | cr == "", 1, all) else logical(0)
    cr <- rbind(cr[keep, , drop = FALSE],
                as.data.frame(row, stringsAsFactors = FALSE))
    added <- added + 1L
  }
  if (added) done <- c(done, sprintf("%d creator(s)", added))
  utils::write.csv(cr, f, row.names = FALSE, na = "")

  # --- attributes and access: the data files describe themselves ------------
  # data/ only, and not recursively: metadata/ is the description itself, not
  # something to describe.
  csvs <- list.files(here("data"), "\\.csv$", full.names = TRUE)
  if (length(csvs)) {
    before <- nrow(.read_meta(file.path(md, "attributes.csv"),
                              colClasses = "character"))
    suppressMessages(dataspice::prep_attributes(
      data_path = csvs, attributes_path = file.path(md, "attributes.csv")))
    suppressMessages(dataspice::prep_access(
      data_path = csvs, access_path = file.path(md, "access.csv")))
    n <- nrow(.read_meta(file.path(md, "attributes.csv"),
                         colClasses = "character")) - before
    if (n > 0) done <- c(done, sprintf("%d variable(s)", n))
  }

  if (!quiet && length(done)) {
    message("Metadata filled in: ", paste(done, collapse = ", "),
            ". The rest is yours: see R/create_metadata.R.")
  }
  invisible(done)
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

#' Record, in renv.lock, the environment this document came out of.
#'
#' Called by the renders that produce a document somebody else will read, and
#' deliberately NOT by render_html(): the .html is the loop you run every two
#' minutes while writing, and it is what you render after renv::restore()ing an
#' old environment to look into a reviewer's complaint. Snapshotting there
#' would silently rewrite your record with the versions you were only visiting.
#'
#' Only the packages the manuscript actually uses, plus their recursive
#' dependencies: something you installed to try out, and never mention in the
#' project, does not travel into the lockfile.
#'
#' Silent when nothing changed, which is most of the time: renv only rewrites
#' the file when the environment really moved.
#' @noRd
.record_env <- function() {
  if (!requireNamespace("renv", quietly = TRUE)) return(invisible(NA))
  # renv prints its report straight to the console rather than through
  # message(), so suppressMessages() below does not reach it: a first render
  # otherwise dumps the whole resolved library, a hundred lines of it, over
  # the render log. This is renv's own switch for that.
  old <- options(renv.verbose = FALSE)
  on.exit(options(old), add = TRUE)
  lock <- here("renv.lock")
  before <- if (file.exists(lock)) unname(tools::md5sum(lock)) else NA_character_
  pkgs <- tryCatch(.analysis_packages(), error = function(e) character(0))
  ok <- tryCatch({
    suppressMessages(
      if (length(pkgs)) {
        renv::snapshot(project = here(), packages = pkgs, prompt = FALSE)
      } else {
        # Nothing detected (an empty template): record everything rather than
        # write a lockfile that promises less than the paper needs.
        renv::snapshot(project = here(), prompt = FALSE)
      })
    TRUE
  }, error = function(e) {
    warning("Could not record the environment: ", conditionMessage(e),
            call. = FALSE, immediate. = TRUE)
    FALSE
  })
  after <- if (file.exists(lock)) unname(tools::md5sum(lock)) else NA_character_
  if (isTRUE(ok) && !identical(before, after)) {
    message("renv.lock updated: it now describes the environment this render ",
            "came out of.")
  }
  invisible(ok)
}

#' Is renv.lock there, and does it match the library actually in use?
#'
#' It LOOKS, it does not write. The writing is done by .record_env(), from the
#' renders that produce a document for someone else; this only reports.
#'
#' @return TRUE in sync, FALSE not, NA if it cannot be determined.
check_renv <- function(quiet = FALSE) {
  if (!requireNamespace("renv", quietly = TRUE)) {
    if (!quiet) message("renv is not installed: the versions are only recorded ",
                        "in output/sessionInfo.txt.")
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

#' Close every table cell that ends in a table, and hand Word a file it will
#' open.
#'
#' Quarto wraps each captioned float in a one-cell table, and a flextable goes
#' inside that cell. The cell then ends with a table, and the OOXML schema
#' requires the last thing in a cell to be a paragraph. Word refuses the file:
#' "Word found unreadable content", and what it offers to recover opens
#' read-only. LibreOffice and Google Docs read it without complaining, which is
#' what makes this so easy to ship without noticing.
#'
#' The repair is one empty paragraph before the cell closes. Nothing else in
#' the package is touched, and a document that does not need it comes back
#' unchanged.
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

#' @noRd
.repair_docx <- function(f) {
  if (!file.exists(f) || !requireNamespace("zip", quietly = TRUE)) {
    return(invisible(FALSE))
  }
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
  # 5.5-inch cell and lost an inch off its right edge. The grid is set to the
  # width the page really has, which is what the table already claims to want.
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
  # The indent pushes that half inch off the right edge and Word clips it: the
  # figure loses its right side. `w:ind` goes before `w:jc`, which is where
  # the schema wants it.
  fixed <- gsub(paste0("(<w:pPr>(?:(?!</w:pPr>).)*?)(<w:jc [^>]*/>)",
                       "(</w:pPr><w:r><w:drawing>)"),
                "\\1<w:ind w:firstLine=\"0\"/>\\2\\3", fixed, perl = TRUE)
  fixed <- gsub(paste0("(<w:pPr>(?:(?!</w:pPr>|<w:ind ).)*?)",
                       "(</w:pPr><w:r><w:drawing>)"),
                "\\1<w:ind w:firstLine=\"0\"/>\\2", fixed, perl = TRUE)

  if (identical(fixed, xml)) {
    unlink(d, recursive = TRUE)
    return(invisible(FALSE))
  }
  writeChar(fixed, x, eos = NULL, useBytes = TRUE)
  # mode = "mirror" keeps the folders; "cherry-pick" would flatten them and
  # the .docx would no longer be a .docx. The order is the package's own, so
  # [Content_Types].xml stays first.
  zip::zip(zipfile = f, files = parts, root = d, mode = "mirror")
  unlink(d, recursive = TRUE)
  message("Repaired ", basename(f), ": ", n, " table cell(s) closed with a ",
          "paragraph, which is what Word needs to open the file.")
  invisible(TRUE)
}


#' Common wrapper. Returns the path of the file produced.
#'
#' The main text comes out WITHOUT the supplementary material and with its
#' citations replaced by their text ("Figure S1"); the supplement comes out
#' beside it, as its own file or files. They are never put back together: a
#' single .docx could only be made by handing both to pandoc, which rebuilds
#' the document instead of copying it and, in the rebuilding, throws away the
#' column widths -- the tables came out of Word with every heading broken
#' across two lines. One document per section is also what a journal asks for.
#'
#' @param blinded if TRUE, the author block is dropped and the document opens
#'   with the title alone (double-blind review).
#' @param supplement FALSE leaves the supplement unrendered. Only for the
#'   deliverable builders: make_submission() and make_preprint() render it
#'   themselves, with their own subset of files and their own names, and would
#'   otherwise render it twice.
.render <- function(fmt, journal, caption_style, ext,
                    blinded = FALSE, suppl_figures = "separate",
                    supplement = TRUE) {
  csl <- here("references_styles", paste0(journal, ".csl"))
  if (!file.exists(csl)) {
    stop("There is no CSL called '", journal, "'. Available: ",
         paste(list_journals(), collapse = ", "), call. = FALSE)
  }
  .check_quarto()
  .check_license(); sync_licenses(quiet = TRUE); sync_metadata(quiet = TRUE)
  check_citations(); check_crossrefs(); check_data()

  # The supplement is rendered on its own, which is the only way it can carry
  # its own reference list: one Quarto render is one citeproc pass and one
  # bibliography.
  #
  # Two exceptions take the old path, rendering manuscript.qmd whole:
  # the .html, which is the working preview and would lose its theme if pandoc
  # rebuilt it, and a project with no supplementary section, which has nothing
  # to separate.
  if (!identical(fmt, "html") && length(.suppl_files())) {
    input <- .build_main_text(journal, caption_style, fmt, blinded = blinded,
                              suppl_figures = suppl_figures)
    on.exit(unlink(input), add = TRUE)
    quarto::quarto_render(input, output_format = fmt, as_job = FALSE)
    produced <- sub("\\.qmd$", paste0(".", ext), input)
    if (identical(ext, "docx")) .repair_docx(produced)

    if (supplement) {
      # With suppl_figures = "main" the floats are already at the end of the
      # main text, so only the supplementary TEXT is rendered on its own --
      # which is where the independent reference list matters.
      keep <- if (suppl_figures == "main") .suppl_float_files() else character(0)
      render_supplementary(journal, caption_style, output_format = fmt,
                           files = setdiff(.suppl_files(), keep),
                           blinded = blinded)
    }
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
  if (!length(produced) || !file.exists(produced)) {
    stop("The render left no file behind. Check the log.", call. = FALSE)
  }
  # Quarto copies figures/ into output-dir. All three outputs embed their
  # images (the .html through embed-resources), so that copy only confuses:
  # the good ones (600 dpi, the ones the journal wants) are in figures/ at the
  # project root.
  unlink(file.path(OUTPUT, "figures"), recursive = TRUE)
  export_figure_formats(quiet = TRUE)
  produced
}

#' @param journal name of a .csl in references_styles/, without the extension
#'   (see list_journals()). NULL, the default, takes the one the manuscript
#'   declares in its own `csl:` line, beside its title and its authors. Naming
#'   one here overrides that for this call only, and changes no file.
#' @param caption_style default | abbrev | nature | compact (see R/crossref_styles.R)
#' The manuscript and its supplement come out as separate documents, each
#' with its own reference list. That is what a journal asks for, and the only
#' way the tables survive: merging them means handing both to pandoc, which
#' rebuilds the document and loses every column width.
render_docx <- function(journal = NULL, caption_style = "default",
                           suppl_figures = "separate") {
  journal <- .resolve_journal(journal)
  f <- .render("docx", journal, caption_style, "docx",
               suppl_figures = suppl_figures)
  dest <- .out(paste0("manuscript_", journal, ".docx"))
  file.rename(f, dest)
  message("Written: ", dest)
  .record_env()
  invisible(dest)
}

render_pdf <- function(journal = NULL, caption_style = "default",
                            suppl_figures = "separate") {
  journal <- .resolve_journal(journal)
  f <- .render("pdf", journal, caption_style, "pdf",
               suppl_figures = suppl_figures)
  dest <- .out("preprint.pdf")
  file.rename(f, dest)
  message("Written: ", dest)
  .record_env()
  invisible(dest)
}

#' Working HTML: much faster than the .docx for checking results as you go.
render_html <- function(journal = NULL, caption_style = "default") {
  journal <- .resolve_journal(journal)
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
#' @param blinded TRUE drops the authors and the affiliations, for the
#'   supplement that travels with a double-blind submission. FALSE, the
#'   default, names the authors under the title, above the affiliations.
render_supplementary <- function(journal = NULL, caption_style = "default",
                                 output_format = "docx", files = NULL,
                                 blinded = FALSE) {
  journal <- .resolve_journal(journal)
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
  # Under "Supporting Information" goes a reference to the paper this belongs
  # to -- authors, title, journal -- because the file is downloaded on its own
  # from the journal's site, with nothing around it to say what it supports.
  reference <- .manuscript_reference(journal, blinded = blinded)
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
    input <- .build_supplementary(files[k], k, n, fmt = output_format,
                                  blinded = blinded)
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
                             crossref = if (is.na(fk)) crossref_metadata(caption_style)
                                        else .suppl_crossref(fk, length(floats), caption_style)),
                        if (is.null(reference)) NULL else list(subtitle = reference)),
      as_job        = FALSE
    )
    if (!file.exists(produced)) {
      stop("Quarto did not leave ", produced, ". Check the log.", call. = FALSE)
    }
    if (identical(ext, "docx")) .repair_docx(produced)
    dest <- .out(if (n == 1L) paste0("supporting_information.", ext)
                 else sprintf("supporting_information_%s.%s", .suppl_name(files[k]), ext))
    if (!file.rename(produced, dest)) {
      stop("Could not move ", produced, " to ", dest, call. = FALSE)
    }
    dests <- c(dests, dest)
    message("Written: ", dest)
  }
  unlink(file.path(OUTPUT, "figures"), recursive = TRUE)
  export_figure_formats(quiet = TRUE)
  .record_env()
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
  out <- .out("analysis_code.R")

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
  writeLines(c(info, "", paste("quarto:", v)), .out("sessionInfo.txt"))
  if (file.exists(here("renv.lock"))) {
    file.copy(here("renv.lock"), .out("renv.lock"), overwrite = TRUE)
  }
  message("Written: ", out)
  invisible(out)
}

# --- Everything ------------------------------------------------------------

make_all <- function(journal = NULL, caption_style = "default") {
  journal <- .resolve_journal(journal)
  render_docx(journal, caption_style)
  render_pdf(journal, caption_style)
  render_supplementary(journal, caption_style)
  export_code()
  message("\nDone. Outputs in output/")
}
