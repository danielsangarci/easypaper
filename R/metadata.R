# ---------------------------------------------------------------------------
# What the project keeps in step with the manuscript: the copyright holders
# of its licences, and the metadata of the data deposit.
# ---------------------------------------------------------------------------

#' Copy the authors into the licences
#'
#' The authors in the YAML of `manuscript.qmd` are the copyright holders of
#' the project: this writes them into the copyright line of `LICENSE-CODE.txt`
#' (MIT) and into the licence notice of `README.md`, between its
#' `<!-- license:start -->` and `<!-- license:end -->` markers. `LICENSE.txt` (CC
#' BY 4.0) is the official text and is never touched. Every render does this
#' on its own; it can be run as many times as you like.
#'
#' @param year The year of the copyright line. This year by default.
#' @param quiet `TRUE` says nothing.
#' @param path The project, or any folder inside it. Left out, the project
#'   the working directory is in -- its root once its `.Rproj` is open -- and,
#'   since this writes into it, in an interactive session the first such call
#'   asks you to allow it, once a session; in a script, name it.
#' @return The holders as written, invisibly.
#' @seealso [sync_metadata()], which does the same for the data deposit.
#' @export
#' @examples
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir, authors = c("Ada Lovelace", "Alan Turing"), git = FALSE)
#' sync_licenses(path = dir)
#' readLines(file.path(dir, "LICENSE-CODE.txt"), n = 3)
#' unlink(dir, recursive = TRUE)
sync_licenses <- function(year = format(Sys.Date(), "%Y"), quiet = FALSE,
                          path = NULL) {
  .enter_project(path)
  holders <- .format_holders(.author_names())

  # MIT: the copyright line is part of its terms
  f <- .p("LICENSE-CODE.txt")
  l <- readLines(f, warn = FALSE)
  i <- grep("^Copyright \\(c\\)", l)[1]
  if (is.na(i)) stop("LICENSE-CODE.txt has no 'Copyright (c) ...' line.", call. = FALSE)
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

#' The separator of a table of data: "\t" for a .tsv; for a .csv, whichever of
#' `,`, `;`, a tab or `|` splits its first lines into the same, largest number
#' of fields -- a spreadsheet in a language with a decimal comma writes `;`.
#' NULL for a file that is not a table of data.
#' @noRd
.data_delim <- function(f) {
  ext <- tolower(tools::file_ext(f))
  if (ext == "tsv") return("\t")
  if (ext != "csv") return(NULL)
  l <- tryCatch(readLines(f, n = 10L, warn = FALSE, encoding = "UTF-8"),
                error = function(e) character(0))
  l <- gsub('"[^"]*"', "", l[nzchar(trimws(l))])   # what is quoted does not split
  if (!length(l)) return(",")
  cand <- c(",", ";", "\t", "|")
  fields <- vapply(cand, function(d) {
    k <- lengths(regmatches(l, gregexpr(d, l, fixed = TRUE)))
    if (length(unique(k)) == 1L) k[1] else 0L
  }, integer(1))
  if (max(fields) == 0L) "," else cand[which.max(fields)]
}

#' A table of data, read with its own separator -- and with the decimal comma
#' that goes with `;` -- or NULL when it is not one, or cannot be read.
#' @noRd
.read_data_table <- function(f, nrows = -1L) {
  sep <- .data_delim(f)
  if (is.null(sep)) return(NULL)
  tryCatch(
    suppressWarnings(utils::read.table(
      f, header = TRUE, sep = sep, quote = "\"", dec = if (sep == ";") "," else ".",
      nrows = nrows, check.names = FALSE, stringsAsFactors = FALSE,
      comment.char = "", fill = TRUE, encoding = "UTF-8", na.strings = c("", "NA"))),
    error = function(e) NULL)
}

#' The files of data/ a deposit carries -- its description, metadata/, and
#' the folder's own README aside -- as paths relative to data/.
#' @noRd
.data_files <- function(dir = .p("data")) {
  f <- list.files(dir, recursive = TRUE)
  f[!startsWith(f, "metadata/") & !basename(f) %in% c("README.md", ".gitkeep", ".DS_Store")]
}

#' Fill in what the data deposit's metadata can know by itself
#'
#' The deposit is described by four `.csv` files in `data/metadata/`, in the
#' format of the dataspice package: `biblio.csv`, `creators.csv`,
#' `attributes.csv` and `access.csv`. Three of their columns are already
#' written down elsewhere in the project -- the title and the keywords of the
#' manuscript; the authors in its YAML, with their affiliations, the email of
#' the corresponding author and their ORCID; the licence of the data, from
#' the project's `LICENSE.txt`; and the variable names inside the data files --
#' and this copies them across. Copying them by
#' hand is how a deposit ends up disagreeing with its paper.
#'
#' It only ever ADDS. A cell you have filled is never touched and a variable
#' you have described is never rewritten, so every render runs it without
#' eating your work. What no machine can guess -- units, descriptions, the
#' temporal and geographic coverage -- is yours to write, with
#' [edit_metadata()].
#'
#' @param quiet `TRUE` says nothing.
#' @param path The project, or any folder inside it. Left out, the project
#'   the working directory is in -- its root once its `.Rproj` is open -- and,
#'   since this writes into it, in an interactive session the first such call
#'   asks you to allow it, once a session; in a script, name it.
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
sync_metadata <- function(quiet = FALSE, path = NULL) {
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
  b <- put(b, "license", .data_license())
  utils::write.csv(b, f, row.names = FALSE, na = "")

  # --- creators: the authors of the paper are the creators of the data ------
  # Each with what the YAML says of them: the affiliations, numbered there
  # and written out in full here; the email, which the corresponding author
  # carries; and the ORCID, as dataspice's `id`. dataspice keeps one `name`
  # field, not a given/family pair: the name goes in whole, exactly as the
  # manuscript writes it. A cell already filled is left as it is.
  f  <- file.path(md, "creators.csv")
  cr <- .read_meta(f, colClasses = "character")
  people <- .creators(yml)
  added <- 0L
  filled <- 0L
  for (p in people) {
    if (!"name" %in% names(cr)) break
    r <- if (nrow(cr)) which(trimws(cr$name) == p[["name"]])[1] else NA_integer_
    if (is.na(r)) {
      row <- as.list(rep("", ncol(cr))); names(row) <- names(cr)
      for (col in intersect(names(p), names(cr))) row[[col]] <- p[[col]]
      keep <- if (nrow(cr)) !apply(is.na(cr) | cr == "", 1, all) else logical(0)
      cr <- rbind(cr[keep, , drop = FALSE],
                  as.data.frame(row, stringsAsFactors = FALSE))
      added <- added + 1L
      next
    }
    for (col in intersect(setdiff(names(p), "name"), names(cr))) {
      if (blank(cr[[col]][r]) && nzchar(p[[col]])) {
        cr[[col]][r] <- p[[col]]
        filled <- filled + 1L
      }
    }
  }
  if (added) done <- c(done, sprintf("%d creator(s)", added))
  if (filled) done <- c(done, sprintf("%d creator detail(s)", filled))
  utils::write.csv(cr, f, row.names = FALSE, na = "")

  # --- attributes and access: the data files describe themselves ------------
  # Every file the deposit carries is listed in access.csv, the way it is
  # distributed; the tables of data also list their variables in
  # attributes.csv. Read here, not by dataspice: it took a .csv for
  # comma-separated whatever its separator -- a ;-separated one became a
  # single variable named "a;b;c" -- and listed nothing but .csv files.
  # Only what is not there yet is added: what you wrote is never touched.
  files <- .data_files()
  if (length(files)) {
    attr_f <- file.path(md, "attributes.csv")
    acc_f  <- file.path(md, "access.csv")
    attrs  <- .read_meta(attr_f, colClasses = "character")
    acc    <- .read_meta(acc_f, colClasses = "character")
    n <- 0L
    new_files <- setdiff(files, acc$fileName)
    for (f in new_files) {
      acc[nrow(acc) + 1L, ] <- NA_character_
      acc$fileName[nrow(acc)] <- f
      acc$name[nrow(acc)] <- tools::file_path_sans_ext(basename(f))
      acc$encodingFormat[nrow(acc)] <- tolower(tools::file_ext(f))
    }
    for (f in setdiff(files, attrs$fileName)) {
      d <- .read_data_table(file.path(.p("data"), f), nrows = 5L)
      if (is.null(d) || !ncol(d)) next
      new <- data.frame(fileName = f, variableName = names(d),
                        description = NA_character_, unitText = NA_character_,
                        stringsAsFactors = FALSE)
      attrs <- rbind(attrs, new[, names(attrs), drop = FALSE])
      n <- n + nrow(new)
    }
    # Written only when something was added: a file you edited stays as it
    # is, byte for byte, render after render.
    if (length(new_files)) utils::write.csv(acc, acc_f, row.names = FALSE, na = "")
    if (n > 0) utils::write.csv(attrs, attr_f, row.names = FALSE, na = "")
    if (n > 0) done <- c(done, sprintf("%d variable(s)", n))
  }

  if (!quiet && length(done)) {
    message("Metadata filled in: ", paste(done, collapse = ", "),
            ". The rest is yours: edit_metadata().")
  }
  invisible(done)
}

#' The licence of the data, as a link: the one the project's LICENSE.txt file
#' holds, read from its first line -- CC BY 4.0 in a new project. Empty when
#' it is not one of the Creative Commons licences, so nothing wrong is
#' written; edit_metadata("biblio") takes it then.
#' @noRd
.data_license <- function() {
  f <- .p("LICENSE.txt")
  if (!file.exists(f)) return("")
  first <- trimws(readLines(f, n = 5L, warn = FALSE))
  first <- first[nzchar(first)][1]
  if (is.na(first)) return("")
  known <- c(
    "^Attribution 4\\.0 International"                   = "https://creativecommons.org/licenses/by/4.0/",
    "^Attribution-ShareAlike 4\\.0 International"        = "https://creativecommons.org/licenses/by-sa/4.0/",
    "^Attribution-NonCommercial 4\\.0 International"     = "https://creativecommons.org/licenses/by-nc/4.0/",
    "^CC0 1\\.0 Universal"                               = "https://creativecommons.org/publicdomain/zero/1.0/")
  hit <- vapply(names(known), grepl, logical(1), x = first)
  if (any(hit)) unname(known[hit][1]) else ""
}

#' dataspice.json, the machine-readable description of the data, and
#' index_metadata.html, the page to read it, compiled from the four .csv files
#' of data/metadata/ as they are now. edit_metadata("write") calls it, and so
#' does every compendium, so a deposit never carries a description older than
#' its files. Returns the two paths.
#' @noRd
.write_metadata <- function() {
  sync_metadata(quiet = TRUE)
  md <- .p("data", "metadata")
  if (!nrow(.read_meta(file.path(md, "attributes.csv"), colClasses = "character"))) {
    stop("There are no data in data/ to describe yet: convert_data() brings ",
         "them in, and their variables are listed on the next render.",
         call. = FALSE)
  }
  # dataspice reads the coordinates of biblio.csv as numbers, and warns
  # once for every one left blank; what it then writes is cleaned below.
  withCallingHandlers(dataspice::write_spice(path = md), warning = function(w) {
    if (grepl("coerci", conditionMessage(w))) invokeRestart("muffleWarning")
  })
  json <- file.path(md, "dataspice.json")
  .clean_spice(json)
  html <- file.path(md, "index_metadata.html")
  suppressMessages(.spice_page(json, html))
  invisible(c(json, html))
}

#' The authors as the creators of the data, as dataspice's creators.csv has
#' them: `name`, `affiliation` -- every one of them, in full, separated by
#' semicolons -- `email` and `id`, the ORCID as a link. Empty strings where
#' the YAML says nothing.
#' @noRd
.creators <- function(own) {
  a   <- .author_list(own)
  aff <- tryCatch(.author_affiliations(own), error = function(e) list())
  out <- lapply(seq_along(a), function(i) {
    x <- a[[i]]
    n <- .person_name(x)
    if (is.null(n) || !nzchar(trimws(n))) return(NULL)
    field <- function(k) {
      v <- if (is.list(x)) x[[k]]
      if (is.character(v) && nzchar(trimws(v[1]))) trimws(v[1]) else ""
    }
    orcid <- field("orcid")
    if (nzchar(orcid) && !grepl("^https?://", orcid)) {
      orcid <- paste0("https://orcid.org/", orcid)
    }
    c(name = trimws(n),
      affiliation = if (i <= length(aff)) paste(aff[[i]], collapse = "; ") else "",
      email = field("email"), id = orcid)
  })
  Filter(Negate(is.null), out)
}

#' Describe the data deposit by hand
#'
#' Opens dataspice's editor for one of the four files that describe the data
#' deposit, in `data/metadata/`: the variables (`"attributes"`: their
#' description and units), the dataset itself (`"biblio"`: description,
#' temporal and geographic coverage), the people (`"creators"`) or the files
#' (`"access"`: the `name` of each is its file name without the extension,
#' to change if you like). Save in the editor and close it.
#' [sync_metadata()] has already filled in what the project knows -- title,
#' keywords, the authors with their affiliations, email and ORCID, variable
#' names -- so what is left is what no machine can guess.
#'
#' `what = "write"` opens nothing: it compiles the four files into
#' `data/metadata/dataspice.json`, the machine-readable description, and
#' writes `data/metadata/index_metadata.html`, a page to read it. You need it
#' only to look at them: [make_submission()] and [make_preprint()] compile
#' them again before they build the data compendium, which carries both.
#'
#' @param what Which file to edit: `"attributes"` (the default), `"biblio"`,
#'   `"creators"` or `"access"`; or `"write"` to compile them.
#' @param path The project, or any folder inside it. Left out, the project
#'   the working directory is in -- its root once its `.Rproj` is open -- and,
#'   since this writes into it, in an interactive session the first such call
#'   asks you to allow it, once a session; in a script, name it.
#' @return The metadata folder, invisibly.
#' @seealso [sync_metadata()], and <https://docs.ropensci.org/dataspice/> for
#'   what each field means.
#' @export
#' @examples
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir, git = FALSE)
#' write.csv(head(iris), file.path(dir, "data", "iris.csv"), row.names = FALSE)
#'
#' edit_metadata("write", path = dir)   # dataspice.json and its web page
#' list.files(file.path(dir, "data", "metadata"))
#'
#' # The editors open in an interactive session.
#' if (interactive()) {
#'   edit_metadata("attributes", path = dir)
#'   edit_metadata("biblio", path = dir)
#' }
#' unlink(dir, recursive = TRUE)
edit_metadata <- function(what = c("attributes", "biblio", "creators",
                                   "access", "write"),
                          path = NULL) {
  .enter_project(path)
  what <- match.arg(what)
  sync_metadata(quiet = TRUE)
  md <- .p("data", "metadata")
  if (identical(what, "write")) {
    w <- .write_metadata()
    message("Written: ", w[1], "\n         ", w[2])
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
#' authors are left out and the reference is title and journal alone. A
#' preprint is in no journal yet: `venue`, the server -- "Preprint, bioRxiv"
#' -- takes the journal's place. The journal, or the server, is in italics,
#' as a reference sets it.
#' @noRd
.manuscript_reference <- function(journal, blinded = FALSE, venue = NULL) {
  who <- if (blinded) character(0) else
    tryCatch(.author_names(), error = function(e) character(0))
  ttl <- rmarkdown::yaml_front_matter(.master())$title
  parts <- c(if (length(who))
               paste(vapply(who, .reference_name, character(1)), collapse = ", "),
             if (!is.null(ttl)) as.character(ttl)[1],
             if (is.null(venue)) paste0("*", .journal_name(journal), "*")
             else paste0("Preprint, *", venue, "*"))
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
