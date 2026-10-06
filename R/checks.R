# ---------------------------------------------------------------------------
# The checks every render runs first.
#
# Neither a broken bibliographic citation nor a broken cross-reference stops
# Quarto: citeproc only warns on stderr, and a reference with no target is
# written as "?@fig-x" into the final document. A Lua filter is no use for
# this either: Quarto resolves cross-references AFTER user filters, so a
# filter cannot tell a broken one from a good one (verified). Hence the
# checks run here, in R, before rendering, where an error really does stop
# everything.
# ---------------------------------------------------------------------------

#' Check a project before rendering it
#'
#' Every render runs these first -- all but `check_renv()`: a render writes
#' `renv.lock` instead -- and stops on what would otherwise reach the
#' document broken. Call them yourself to know before waiting for a render:
#' called on their own, they also say in one line when all is well; inside a
#' render, only what is not.
#'
#' * `check_citations()`: every `@key` cited in the text has an entry in
#'   `references/*.bib`. Package citations (`@R-pkg`) are written by the
#'   render itself, so a new one is only announced.
#' * `check_crossrefs()`: every `@fig-`, `@tbl-`, `@sfig-`... cited has a
#'   figure or table with that label, and says which ones exist but are never
#'   cited -- journals ask for every figure to be cited in the text. A
#'   citation written inside a string of R code counts as cited.
#' * `check_packages()`: every package the manuscript, its sections and
#'   `R/setup.R` load with `library()` or `require()` is installed. A missing
#'   one otherwise surfaces a minute into the render, from inside Quarto.
#' * `check_title()`: the manuscript has a title of its own, not the
#'   template's. It is written once, in the YAML of `manuscript.qmd`.
#' * `check_data()`: every file the analysis names is in `data/`, and which
#'   files there nothing reads -- they would travel to the data repository all
#'   the same. It reports; it never removes.
#' * `check_renv()`: `renv.lock` is there and matches the library in use.
#'
#' An e-mail address is not a citation, however it is written: an `@` glued to
#' a letter or a digit -- any letter, accented ones too -- is an address, and
#' `\@` is a literal `@`, which is what RStudio's visual editor writes. That is
#' pandoc's own rule, and pandoc decides what gets cited.
#'
#' @param quiet `TRUE` keeps the notes to yourself and only stops or warns on
#'   what is wrong.
#' @param path The project, or any folder inside it. The working directory by
#'   default, which is the project root once its `.Rproj` is open.
#' @return `check_citations()`, `check_crossrefs()` and `check_packages()`
#'   return `TRUE` invisibly and stop with an error naming what is missing.
#'   `check_title()` and `check_data()` return `TRUE` or `FALSE` invisibly,
#'   with a warning when `FALSE`. `check_renv()` returns `TRUE` in sync,
#'   `FALSE` not, `NA` when it cannot tell.
#' @seealso [check_species()] for the scientific names of the references, and
#'   [render_docx()], which runs every one of these first.
#' @name checks
#' @examples
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir, title = "Ant colonies", git = FALSE)
#' check_citations(dir)
#' check_crossrefs(path = dir)
#' check_title(path = dir)
#' check_data(path = dir)
#' unlink(dir, recursive = TRUE)
NULL

# --- Citations -----------------------------------------------------------------

CROSSREF_PREFIXES <- c("fig", "tbl", "eq", "sec", "lst", "thm", "lem", "cor",
                       "prp", "cnj", "def", "exm", "exr", "sfig", "stbl")

#' @noRd
.bib_keys <- function() {
  bibs <- list.files(.p("references"), "\\.bib$", full.names = TRUE)
  keys <- unlist(lapply(bibs, function(f) {
    l <- readLines(f, warn = FALSE)
    m <- regmatches(l, regexpr("^\\s*@[A-Za-z]+\\s*\\{\\s*[^,]+", l))
    sub("^\\s*@[A-Za-z]+\\s*\\{\\s*", "", m)
  }))
  trimws(unique(keys))
}

#' Every @... key in a file, with code and comments already stripped out.
#' @noRd
.at_keys <- function(f) {
  .at_keys_text(readLines(f, warn = FALSE, encoding = "UTF-8"))
}

#' The same, on lines already read.
#' @noRd
.at_keys_text <- function(txt) {
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

  # Pandoc's rule: an @ glued to a letter or a digit is an e-mail address, not
  # a citation -- any letter, accented ones too -- and "\\@" is a literal @,
  # the way to write one next to a space.
  m <- gregexpr("(?<![\\p{L}\\p{N}_\\\\])@[A-Za-z][A-Za-z0-9_:.#$%&+/-]*", txt,
                perl = TRUE)
  k <- unlist(regmatches(txt, m))
  k <- sub("^@", "", k)
  sub("[.,;:]+$", "", k)                            # trailing punctuation
}

#' @noRd
.is_crossref <- function(k) sub("-.*$", "", k) %in% CROSSREF_PREFIXES

#' Cross-references written inside the strings of R code.
#'
#' .at_keys() strips code out, and it has to: the S4 `@` operator is not a
#' citation. But a sprintf("... (@fig-x)") in a chunk, shown with an inline
#' R expression, or a function in R/setup.R that returns "see @stbl-raw", does
#' put a citation in the document -- and check_crossrefs() reported those
#' figures as never cited, on every render. So the string literals of the code
#' are read too: the R chunks and inline expressions of the manuscript files, and every
#' .R file in R/.
#'
#' Only a whole label counts, one that ends in a letter, digit or underscore:
#' "@fig-%s" or paste0("@fig-", id) are built at run time and cannot be read
#' from here.
#' @noRd
.code_keys <- function(files) {
  rx <- "(?<![\\p{L}\\p{N}_\\\\])@[A-Za-z]+-[A-Za-z0-9_:.-]*[A-Za-z0-9_]"
  from_code <- function(code) {
    pd <- tryCatch(utils::getParseData(parse(text = code, keep.source = TRUE)),
                   error = function(e) NULL)
    if (is.null(pd) || !nrow(pd)) return(character(0))
    s <- pd$text[pd$token == "STR_CONST"]
    sub("^@", "", unlist(regmatches(s, gregexpr(rx, s, perl = TRUE))))
  }
  in_qmd <- unlist(lapply(files, function(f) {
    l <- readLines(f, warn = FALSE, encoding = "UTF-8")
    fence <- grepl("^\\s*```", l)
    opens <- grepl("^\\s*```+\\s*\\{r[ ,}]", l)
    code  <- character(0); prose <- character(0); cur <- NULL
    for (i in seq_along(l)) {
      if (is.null(cur) && opens[i]) { cur <- character(0); next }
      if (!is.null(cur) && fence[i]) {
        code <- c(code, paste(cur, collapse = "\n")); cur <- NULL; next
      }
      if (!is.null(cur)) cur <- c(cur, l[i]) else prose <- c(prose, l[i])
    }
    inline <- unlist(regmatches(prose, gregexpr("`r [^`]+`", prose)))
    inline <- sub("^`r ", "", sub("`$", "", inline))
    unlist(lapply(c(code, inline), from_code))
  }))
  rfiles <- list.files(.p("R"), "\\.R$", full.names = TRUE)
  in_r <- unlist(lapply(rfiles, function(f) {
    from_code(paste(readLines(f, warn = FALSE), collapse = "\n"))
  }))
  unique(c(in_qmd, in_r))
}

#' Figure/table/section labels defined in the manuscript files:
#' "#| label: fig-x" in chunks and "{#sfig-x}" in divs and headers.
#' @noRd
.crossref_labels <- function(files) {
  unlist(lapply(files, function(f) {
    txt <- readLines(f, warn = FALSE)
    chunk <- regmatches(txt, regexpr("(?<=^#\\| label: )[A-Za-z0-9_:.-]+", txt,
                                     perl = TRUE))
    div <- unlist(regmatches(txt, gregexpr("(?<=\\{#)[A-Za-z0-9_:.-]+", txt,
                                           perl = TRUE)))
    c(chunk, div)
  }))
}

#' @rdname checks
#' @export
check_citations <- function(path = ".") {
  # Called on its own, it also says when all is well, and which package
  # citations the render will write; inside a render, only what is wrong.
  alone <- is.null(.ep$root)
  .enter_project(path)
  files <- c(.master(), .section_files())
  cited <- unique(Filter(Negate(.is_crossref), unlist(lapply(files, .at_keys))))
  if (!length(cited)) {
    if (alone) message("Citations: none in the text yet.")
    return(invisible(TRUE))
  }

  missing <- setdiff(cited, .bib_keys())
  # The R-* keys are written by write_packages_bib() at the end of the render:
  # the first time you cite a package they are not in packages.bib yet.
  pending <- grep("^R-", missing, value = TRUE)
  missing <- setdiff(missing, pending)

  if (length(missing)) {
    stop("Citations with no entry in references/*.bib: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  found <- length(cited) - length(pending)
  if (alone && found) {
    message("Citations: all ", found, " found in references/*.bib.")
  }
  if (alone && length(pending)) {
    message("Package citations not generated yet (they will appear after the ",
            "render): ", paste(pending, collapse = ", "))
  }
  invisible(TRUE)
}

#' @rdname checks
#' @export
check_crossrefs <- function(quiet = FALSE, path = ".") {
  # Called on its own, it also says when all is well; inside a render, only
  # what is not.
  alone <- is.null(.ep$root)
  .enter_project(path)
  files <- c(.master(), .section_files())
  cited   <- unique(Filter(.is_crossref, unlist(lapply(files, .at_keys))))
  in_code <- unique(Filter(.is_crossref, .code_keys(files)))
  defined <- unique(Filter(.is_crossref, .crossref_labels(files)))

  # Only a citation written in the prose stops the render. One read out of a
  # string in the code is evidence, not proof -- the string may never be
  # printed -- so it can silence the note below and raise one of its own, but
  # it never stops anything.
  missing <- setdiff(cited, defined)
  if (length(missing)) {
    stop("Cross-references with no target: ", paste(missing, collapse = ", "),
         "\n  Either that figure/table does not exist, or the label is ",
         "misspelled.", call. = FALSE)
  }
  if (alone && !quiet) {
    message(if (length(cited)) {
      paste0("Cross-references: all ", length(cited), " resolve.")
    } else "Cross-references: none in the text yet.")
  }
  ghosts <- setdiff(in_code, defined)
  if (length(ghosts) && !quiet) {
    message("Note: cited from R code, but no figure or table has that label: ",
            paste(ghosts, collapse = ", "))
  }
  orphans <- setdiff(defined, c(cited, in_code))
  if (length(orphans) && !quiet) {
    message("Note: defined but never cited in the text: ",
            paste(orphans, collapse = ", "))
  }
  invisible(TRUE)
}

#' @rdname checks
#' @export
check_packages <- function(path = ".") {
  alone <- is.null(.ep$root)
  .enter_project(path)
  # Only library() and require() are read, because those are what stop a
  # render: a pkg::fn() may sit behind a requireNamespace() and be fine.
  files <- c(.master(), .p("supplementary.qmd"), .p("title_page.qmd"),
             list.files(.p("_sections"), "[.]qmd$", full.names = TRUE),
             list.files(.p("R"), "^(setup|analysis.*)[.]R$", full.names = TRUE))
  files <- files[file.exists(files)]
  txt <- unlist(lapply(files, readLines, warn = FALSE, encoding = "UTF-8"))
  txt <- sub("#.*$", "", txt)                       # comments, and #| options
  calls <- unlist(regmatches(txt, gregexpr(
    "\\b(library|require)\\(\\s*[\"']?[A-Za-z][A-Za-z0-9.]*", txt, perl = TRUE)))
  pkgs <- sort(unique(sub("^.*\\(\\s*[\"']?", "", calls)))
  missing <- pkgs[!nzchar(vapply(pkgs, function(p) system.file(package = p), ""))]
  if (length(missing)) {
    stop("The manuscript loads packages that are not installed: ",
         paste(missing, collapse = ", "), ".\n  Install them with:  ",
         "install.packages(c(", paste0('"', missing, '"', collapse = ", "), "))",
         call. = FALSE)
  }
  if (alone && length(pkgs)) {
    message("Packages: all ", length(pkgs), " the manuscript loads are installed.")
  }
  invisible(TRUE)
}

#' @rdname checks
#' @export
check_title <- function(quiet = FALSE, path = ".") {
  .enter_project(path)
  # The title lives in one place, the YAML of manuscript.qmd: the title page
  # and the README's heading are given it.
  ms <- rmarkdown::yaml_front_matter(.master())$title
  if (is.null(ms) || !nzchar(trimws(paste(ms, collapse = ""))) ||
      identical(ms, TEMPLATE_TITLE)) {
    warning("manuscript.qmd still has the template's title (\"", TEMPLATE_TITLE,
            "\"). Write the real one in its YAML: the title page, the README ",
            "and the deposit's metadata take it from there.",
            call. = FALSE, immediate. = TRUE)
    return(invisible(FALSE))
  }
  if (!quiet) message("Title: ", ms)
  invisible(TRUE)
}

#' @rdname checks
#' @export
check_data <- function(quiet = FALSE, path = ".") {
  alone <- is.null(.ep$root)
  .enter_project(path)
  # data/ is not "my clean data", it is "what I am going to publish": the
  # compendium copies it whole and sync_metadata() describes every file in
  # it. A .csv from a path you abandoned travels to the repository and gets
  # listed in the metadata, and nothing tells you.
  #
  # It reports; it never removes. A file read through a path the code builds
  # -- paste0("data/", species, ".csv"), a loop over list.files() -- is
  # invisible to any scan, so dropping the ones that look unused would sooner
  # or later publish a compendium with a hole in it. Shipping one file too
  # many is a nuisance; shipping one too few breaks the reproduction.
  dir <- .p("data")
  if (!dir.exists(dir)) return(invisible(TRUE))
  # metadata/ describes the data, it is not data, and neither is the folder's
  # own README.
  present <- list.files(dir, recursive = TRUE)
  present <- present[!startsWith(present, "metadata/") & present != "README.md"]
  if (!length(present)) {
    if (alone && !quiet) message("Data: data/ is empty.")
    return(invisible(TRUE))
  }

  # The same files the compendium publishes: the paper and the analysis code.
  src <- c(.master(), .section_files(), .p("R/setup.R"),
           list.files(.p("R"), "^analysis.*[.]R$", full.names = TRUE))
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
  } else if (alone && !quiet && length(read)) {
    message("Data: all ", length(read), " file(s) the analysis reads are in data/.")
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
    .say_once("unused-data", "Note: in data/ but never read by the analysis: ",
            paste(unused, collapse = ", "), "\n  They travel into the ",
            "compendium and into its metadata all the same. Move them out of ",
            "data/ if they are not part of the paper.")
  }
  invisible(!length(missing))
}

#' @rdname checks
#' @export
check_renv <- function(quiet = FALSE, path = ".") {
  .enter_project(path)
  # It LOOKS, it does not write. The writing is done by the renders that
  # produce a document for someone else; this only reports.
  if (!file.exists(.p("renv.lock"))) {
    warning("There is no renv.lock: the submission would go out with no ",
            "record of the package versions. Any render_docx() writes one.",
            call. = FALSE, immediate. = TRUE)
    return(invisible(FALSE))
  }
  # renv::status() compares the lockfile against renv's ISOLATED project
  # library. Without renv::init() there is no such library, and status would
  # report "not synchronized" for every project that simply keeps a lockfile
  # written from the user's own library -- which is how easypaper uses it.
  if (!file.exists(.p("renv/activate.R")) && !dir.exists(.p("renv/library"))) {
    if (!quiet) {
      n <- tryCatch(length(jsonlite::read_json(.p("renv.lock"))$Packages),
                    error = function(e) NA_integer_)
      message("renv.lock present (", n, " packages), written from your own ",
              "library. make_submission() refreshes it on every submission.")
    }
    return(invisible(NA))
  }
  st <- tryCatch(suppressMessages(renv::status(project = .p())),
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

# --- Authors -------------------------------------------------------------------

TEMPLATE_AUTHORS <- c("Author1", "Author2")
TEMPLATE_TITLE   <- "Manuscript title here"

#' The author names in the YAML of manuscript.qmd, affiliation marks stripped.
#' @noRd
.author_names <- function() {
  yml <- rmarkdown::yaml_front_matter(.master())
  a <- yml$author
  if (is.null(a)) {
    stop("The YAML of manuscript.qmd has no 'author' field.", call. = FALSE)
  }
  if (!is.list(a)) a <- as.list(a)
  names_ <- vapply(a, function(x) {
    n <- .person_name(x)
    if (is.null(n)) NA_character_ else n
  }, character(1))
  # Strip the affiliation marks: "First Author^1,\\*^" -> "First Author"
  names_ <- gsub("\\^[^^]*\\^", "", names_)
  names_ <- trimws(gsub("[\\\\*,]+$", "", trimws(names_)))
  names_ <- names_[!is.na(names_) & nzchar(names_)]
  if (!length(names_)) {
    stop("Could not read any author name from the YAML.", call. = FALSE)
  }
  names_
}

#' Warn if the YAML still carries the template authors.
#' @noRd
.check_license <- function() {
  names_ <- .author_names()
  leftovers <- intersect(names_, TEMPLATE_AUTHORS)
  if (length(leftovers)) {
    warning("The YAML of manuscript.qmd still has template authors (",
            paste(leftovers, collapse = ", "), "). Replace them with the real ",
            "ones: they are where the copyright holders of LICENSE-CODE.txt and of ",
            "the README come from.", call. = FALSE, immediate. = TRUE)
  }
  invisible(length(leftovers) == 0)
}
