# ---------------------------------------------------------------------------
# What the project keeps in step with the manuscript: the copyright holders
# of its licences, and the metadata of the data deposit.
# ---------------------------------------------------------------------------

#' Copy the authors into the licences
#'
#' The authors in the YAML of `manuscript.qmd` are the copyright holders of
#' the project: this writes them into the copyright line of `LICENSE-CODE`
#' (MIT) and into the licence notice of `README.md`, between its
#' `<!-- license:start -->` and `<!-- license:end -->` markers. `LICENSE` (CC
#' BY 4.0) is the official text and is never touched. Every render does this
#' on its own; it can be run as many times as you like.
#'
#' @param year The year of the copyright line. This year by default.
#' @param quiet `TRUE` says nothing.
#' @param path The project, or any folder inside it. The working directory by
#'   default, which is the project root once its `.Rproj` is open.
#' @return The holders as written, invisibly.
#' @seealso [sync_metadata()], which does the same for the data deposit.
#' @export
#' @examples
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir, authors = c("Ada Lovelace", "Alan Turing"), git = FALSE)
#' sync_licenses(path = dir)
#' readLines(file.path(dir, "LICENSE-CODE"), n = 3)
#' unlink(dir, recursive = TRUE)
sync_licenses <- function(year = format(Sys.Date(), "%Y"), quiet = FALSE,
                          path = ".") {
  .enter_project(path)
  holders <- .format_holders(.author_names())

  # MIT: the copyright line is part of its terms
  f <- .p("LICENSE-CODE")
  l <- readLines(f, warn = FALSE)
  i <- grep("^Copyright \\(c\\)", l)[1]
  if (is.na(i)) stop("LICENSE-CODE has no 'Copyright (c) ...' line.", call. = FALSE)
  l[i] <- sprintf("Copyright (c) %s %s", year, holders)
  writeLines(l, f)

  # README: licence notice for the content, between markers.
  f2 <- .p("README.md")
  r <- readLines(f2, warn = FALSE)
  a <- grep("<!-- license:start", r, fixed = TRUE)[1]
  b <- grep("<!-- license:end", r, fixed = TRUE)[1]
  if (is.na(a) || is.na(b) || b <= a) {
    stop("Cannot find the license:start / license:end markers in README.md.",
         call. = FALSE)
  }
  notice <- c(
    sprintf("> (c) %s %s. The text, figures, tables and data of this compendium",
            year, holders),
    "> are licensed under",
    "> [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)."
  )
  writeLines(c(r[seq_len(a)], notice, r[b:length(r)]), f2)

  if (!quiet) message("Copyright holders: ", holders, " (", year, ")")
  invisible(holders)
}

#' "A", "A & B", "A, B & C"
#' @noRd
.format_holders <- function(n) {
  if (length(n) == 1) return(n)
  paste(paste(n[-length(n)], collapse = ", "), "&", n[length(n)])
}

# --- The data deposit's metadata ---------------------------------------------------

#' Read one of the deposit's metadata .csv files.
#'
#' dataspice writes its scaffold without a final newline, and read.csv warns
#' about that on every render until the file has been written back once. The
#' warning says nothing about the data, which reads correctly, so it is
#' muffled -- and only that one: any other warning the read raises still
#' reaches you.
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

#' Fill in what the data deposit's metadata can know by itself
#'
#' The deposit is described by four `.csv` files in `data/metadata/`, in the
#' format of the dataspice package: `biblio.csv`, `creators.csv`,
#' `attributes.csv` and `access.csv`. Three of their columns are already
#' written down elsewhere in the project -- the title and the keywords in the
#' YAML of the manuscript, the authors in the same block, and the variable
#' names inside the data files -- and this copies them across. Copying them by
#' hand is how a deposit ends up disagreeing with its paper.
#'
#' It only ever ADDS. A cell you have filled is never touched and a variable
#' you have described is never rewritten, so every render runs it without
#' eating your work. What no machine can guess -- units, descriptions, the
#' temporal and geographic coverage -- is yours to write, with
#' [edit_metadata()].
#'
#' @param quiet `TRUE` says nothing.
#' @param path The project, or any folder inside it. The working directory by
#'   default, which is the project root once its `.Rproj` is open.
#' @return What was filled in, as a character vector, invisibly.
#' @seealso [edit_metadata()] for the rest.
#' @export
#' @examples
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir, title = "Ant colonies", authors = "Ada Lovelace",
#'              git = FALSE)
#' write.csv(data.frame(colony = 1:3, richness = c(4, 7, 5)),
#'           file.path(dir, "data", "colonies.csv"), row.names = FALSE)
#' sync_metadata(path = dir)
#' read.csv(file.path(dir, "data", "metadata", "attributes.csv"))
#' unlink(dir, recursive = TRUE)
sync_metadata <- function(quiet = FALSE, path = ".") {
  .enter_project(path)
  # create_spice() copies its templates with file.copy() and no overwrite, so
  # anything already filled in survives being called again.
  suppressMessages(dataspice::create_spice(dir = .p("data")))
  md   <- .p("data", "metadata")
  yml  <- rmarkdown::yaml_front_matter(.master())
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
  b <- put(b, "keywords", paste(.keywords(), collapse = ", "))
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
  # data/ only, and not recursively: metadata/ is the description itself.
  csvs <- list.files(.p("data"), "\\.csv$", full.names = TRUE)
  if (length(csvs)) {
    before <- nrow(.read_meta(file.path(md, "attributes.csv"),
                              colClasses = "character"))
    # One file at a time, never the whole vector. dataspice 1.1.1 only builds
    # its list of files when it is handed a single path, so two or more
    # stopped with "object 'file_paths' not found" -- and since every render
    # calls this, a project with two .csv files could not render at all.
    #
    # And only the files not yet described. dataspice would skip the others
    # by itself, but with a warning each, on every render.
    attr_f <- file.path(md, "attributes.csv")
    acc_f  <- file.path(md, "access.csv")
    known  <- function(f) {
      x <- .read_meta(f, colClasses = "character")$fileName
      if (is.null(x)) character(0) else x
    }
    for (csv in csvs[!basename(csvs) %in% known(attr_f)]) {
      suppressMessages(dataspice::prep_attributes(
        data_path = csv, attributes_path = attr_f))
    }
    for (csv in csvs[!basename(csvs) %in% known(acc_f)]) {
      suppressMessages(dataspice::prep_access(
        data_path = csv, access_path = acc_f))
    }
    n <- nrow(.read_meta(attr_f, colClasses = "character")) - before
    if (n > 0) done <- c(done, sprintf("%d variable(s)", n))
  }

  if (!quiet && length(done)) {
    message("Metadata filled in: ", paste(done, collapse = ", "),
            ". The rest is yours: edit_metadata().")
  }
  invisible(done)
}

#' Describe the data deposit by hand
#'
#' Opens dataspice's editor for one of the four files that describe the data
#' deposit, in `data/metadata/`: the variables (`"attributes"`: their
#' description and units), the dataset itself (`"biblio"`: description,
#' temporal and geographic coverage), the people (`"creators"`: affiliations,
#' ORCID) or the files (`"access"`). Save in the editor and close it.
#' [sync_metadata()] has already filled in what the project knows -- title,
#' keywords, authors, variable names -- so what is left is what no machine can
#' guess.
#'
#' `what = "write"` opens nothing: it compiles the four files into
#' `data/metadata/dataspice.json`, the machine-readable description, and
#' writes `data/metadata/index_metadata.html`, a page to read it. The data
#' compendium of [make_submission()] carries both.
#'
#' @param what Which file to edit: `"attributes"` (the default), `"biblio"`,
#'   `"creators"` or `"access"`; or `"write"` to compile them.
#' @param path The project, or any folder inside it. The working directory by
#'   default, which is the project root once its `.Rproj` is open.
#' @return The metadata folder, invisibly.
#' @seealso [sync_metadata()], and <https://docs.ropensci.org/dataspice/> for
#'   what each field means.
#' @export
#' @examples
#' \dontrun{
#' # Inside a project, with its .Rproj open. The editors are interactive.
#' edit_metadata("attributes")   # units and descriptions of every variable
#' edit_metadata("biblio")       # what the dataset is, when and where
#' edit_metadata("write")        # dataspice.json and its web page
#' }
edit_metadata <- function(what = c("attributes", "biblio", "creators",
                                   "access", "write"),
                          path = ".") {
  .enter_project(path)
  what <- match.arg(what)
  sync_metadata(quiet = TRUE)
  md <- .p("data", "metadata")
  if (identical(what, "write")) {
    # dataspice reads the coordinates of biblio.csv as numbers, and warns
    # once for every one left blank; what it then writes is cleaned below.
    withCallingHandlers(dataspice::write_spice(path = md), warning = function(w) {
      if (grepl("coerci", conditionMessage(w))) invokeRestart("muffleWarning")
    })
    json <- file.path(md, "dataspice.json")
    .clean_spice(json)
    html <- file.path(md, "index_metadata.html")
    .spice_page(json, html)
    message("Written: ", json, "\n         ", html)
    return(invisible(md))
  }
  if (!interactive()) {
    stop("edit_metadata(\"", what, "\") opens an editor, which needs an ",
         "interactive session.", call. = FALSE)
  }
  editor <- switch(what,
                   attributes = dataspice::edit_attributes,
                   biblio     = dataspice::edit_biblio,
                   creators   = dataspice::edit_creators,
                   access     = dataspice::edit_access)
  editor(metadata_dir = md)
  invisible(md)
}

# --- The manuscript, named -------------------------------------------------------

#' The journal's name as its own .csl declares it.
#'
#' The argument you pass around is a file name -- "journal-of-ecology" --
#' and the style itself carries the name a reader expects to see. Falls back
#' to the file name when there is no such style or it has no title.
#' @noRd
.journal_name <- function(journal) {
  f <- tryCatch(.csl_path(journal), error = function(e) NULL)
  if (is.null(f)) return(journal)
  x <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = " ")
  t <- regmatches(x, regexpr("<title>[^<]*</title>", x))
  if (!length(t)) return(journal)
  nm <- trimws(gsub("<[^>]+>", "", t[1]))
  if (nzchar(nm)) nm else journal
}

#' dataspice.json with what was left blank taken out, instead of written as
#' if it were known: a box of "NA NA NA NA" for the coordinates, "NA/NA" for
#' the dates, empty strings and nulls. A deposit's metadata says nothing
#' rather than something false.
#' @noRd
.clean_spice <- function(json) {
  j <- tryCatch(jsonlite::read_json(json), error = function(e) NULL)
  if (!is.list(j)) return(invisible(json))
  na <- function(x) is.character(x) && length(x) == 1L && grepl("\\bNA\\b", x)
  # One date known is an open interval, which schema.org writes with "..".
  tc <- j$temporalCoverage
  if (na(tc)) {
    tc <- gsub("\\bNA\\b", "..", tc)
    j$temporalCoverage <- if (identical(tc, "../..")) NULL else tc
  }
  box <- j$spatialCoverage$geo$box
  if (is.null(box) || na(box)) j$spatialCoverage$geo <- NULL
  if (is.list(j$spatialCoverage) && is.null(j$spatialCoverage$geo) &&
      !nzchar(paste(unlist(j$spatialCoverage$name), collapse = ""))) {
    j$spatialCoverage <- NULL
  }
  empty <- vapply(j, function(x) is.null(x) || identical(x, "") ||
                    (is.list(x) && !length(x)), logical(1))
  j <- j[!empty]
  jsonlite::write_json(j, json, auto_unbox = TRUE, pretty = TRUE, null = "null")
  invisible(json)
}

#' The web page of dataspice.json. dataspice's build_site() stops on a file
#' with no dates or no coordinates, which .clean_spice() takes out when they
#' were left blank, so the page is built from a copy that has them back, as
#' blanks.
#' @noRd
.spice_page <- function(json, html) {
  j <- jsonlite::read_json(json)
  if (is.null(j$temporalCoverage)) j$temporalCoverage <- "NA/NA"
  j$temporalCoverage <- gsub("..", "NA", j$temporalCoverage, fixed = TRUE)
  if (is.null(j$spatialCoverage$geo$box)) {
    j$spatialCoverage <- list(`type` = "Place", name = NULL,
                              geo = list(`type` = "GeoShape", box = "NA NA NA NA"))
  }
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  jsonlite::write_json(j, tmp, auto_unbox = TRUE, pretty = TRUE, null = "null")
  suppressWarnings(dataspice::build_site(path = tmp, out_path = html))
  invisible(html)
}

#' One name the way a reference writes it: "Ada Lovelace" -> "Lovelace, A."
#'
#' The last word is taken as the family name and the rest as given names.
#' That is right for most, and wrong for a particle somebody wants kept --
#' "van der Berg" comes out as "Berg, V. D.".
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
  ttl <- rmarkdown::yaml_front_matter(.master())$title
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

#' The keywords of the manuscript: the `Keywords:` line written under the
#' abstract, in _sections/ -- `**Keywords:** ants, mimicry; parasitism` --
#' split on commas and semicolons. Without that line, the `keywords:` of the
#' YAML of manuscript.qmd, Quarto's own field, is read instead.
#' @noRd
.keywords <- function() {
  files <- list.files(.p("_sections"), "[.]qmd$", full.names = TRUE)
  for (f in files[.section_order(basename(files))]) {
    txt <- readLines(f, warn = FALSE, encoding = "UTF-8")
    # Code chunks and comments are not the text of the paper.
    fence <- grepl("^\\s*```", txt)
    txt <- txt[!(cumsum(fence) %% 2 == 1 | fence)]
    txt <- strsplit(gsub("(?s)<!--.*?-->", "",
                         paste(txt, collapse = "\n"), perl = TRUE), "\n")[[1]]
    plain <- gsub("[*_]", "", txt)
    hit <- grep("^\\s*key ?words?\\s*[:.]", plain, ignore.case = TRUE,
                perl = TRUE)
    if (length(hit)) {
      k <- sub("^\\s*key ?words?\\s*[:.]\\s*", "", plain[hit[1]],
               ignore.case = TRUE, perl = TRUE)
      k <- trimws(unlist(strsplit(k, "[,;]")))
      k <- sub("[.]$", "", k)
      return(k[nzchar(k)])
    }
  }
  yml <- rmarkdown::yaml_front_matter(.master())
  as.character(unlist(yml$keywords))
}
