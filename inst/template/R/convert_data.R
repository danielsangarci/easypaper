# ---------------------------------------------------------------------------
# convert_data() -- originals in, open formats out.
#
# This file is the canonical copy. create_paper() writes an identical one into
# each project's R/, so a project keeps working with easypaper uninstalled.
# That is why it uses base R only (tools, utils) and reaches for readxl or
# haven just for the files that need them, and why its helpers carry the .cd_
# prefix instead of sharing the package's: the file has to stand on its own.
# tests/testthat/test-convert_data.R checks the two copies never drift apart.
# ---------------------------------------------------------------------------

.cd_open_formats <- c(
  "csv", "tsv", "txt", "json", "geojson", "xml", "yml", "yaml",  # text
  "parquet", "nc", "h5", "hdf5", "sqlite", "db", "gpkg",         # containers
  "shp", "shx", "dbf", "prj", "cpg", "sbn", "sbx", "qix",        # a shapefile
  "kml", "gml", "tif", "tiff", "asc",                            # spatial
  "fasta", "fa", "fastq", "fq", "nwk", "tre"                     # sequences
)

# The closed formats this converts, and the package each one needs.
.cd_converters <- c(xlsx = "readxl", xls = "readxl",
                    sav = "haven", dta = "haven", sas7bdat = "haven")

#' Convert or copy originals into the project's data folder
#'
#' The project publishes what is in `data/`: the analysis reads it, the
#' metadata describes it and the submission compendium carries it. This brings
#' an original into that folder in a format that will still open in twenty
#' years. It never writes anywhere else and never touches the original.
#'
#' Each file takes one of three roads, decided by its extension alone:
#'
#' * **Converted** to `.csv`: `.xlsx` and `.xls`, one `.csv` per sheet (needs
#'   readxl); `.sav`, `.dta` and `.sas7bdat`, one `.csv` per file (needs
#'   haven). These are closed formats with an open equivalent faithful enough
#'   to publish. A file that cannot be read -- corrupt, or not really what its
#'   extension says -- is named in a warning and skipped, and the rest of the
#'   batch goes on. A missing readxl or haven is reported once per call, with
#'   the files it held back.
#' * **Copied byte for byte**, because they already are the open format and
#'   converting one would destroy it rather than open it:
#'   * text and tables: `.csv`, `.tsv`, `.txt`, `.json`, `.geojson`, `.xml`,
#'     `.yml`, `.yaml`
#'   * containers: `.parquet`, `.nc`, `.h5`, `.hdf5`, `.sqlite`, `.db`,
#'     `.gpkg`
#'   * spatial: `.shp` with its sidecars (`.shx`, `.dbf`, `.prj`, `.cpg`,
#'     `.sbn`, `.sbx`, `.qix`), `.kml`, `.gml`, `.tif`, `.tiff`, `.asc`
#'   * sequences and trees: `.fasta`, `.fa`, `.fastq`, `.fq`, `.nwk`, `.tre`
#' * **Named on screen and left where it is**: anything else. A proprietary
#'   instrument file, an ArcGIS project, a photograph of a field notebook --
#'   nothing here can tell whether it belongs in the paper, or what "the
#'   table" inside it would even be.
#'
#' That second list is `.cd_open_formats`, at the top of this file. Print it to
#' see what is in it, add to it when your field uses something it has not heard
#' of, or pass the extension in `also` for a single call. The file lives in
#' your project, so the list is yours to edit.
#'
#' A format conversion, not a transformation: filtering, recoding and cleaning
#' belong in the analysis chunk that needs them, where a reader can check them.
#' Every conversion costs something -- an `.xlsx` loses its formulas, an `.sav`
#' its value labels -- which is why the original is never moved or altered.
#'
#' Subfolders of a source folder are read but not reproduced: everything lands
#' flat in `data/`. When two originals want the same name there, one keeps it
#' -- whichever comes first in alphabetical order by path -- and the rest are
#' refused with a warning saying which was kept and which was not, rather than
#' one table quietly overwriting another. Names that differ only in case count
#' as the same name, because the deposit has to unpack on a file system that
#' cannot tell `Counts.csv` from `counts.csv`.
#'
#' @param path File or folder to read, as a single string: relative to the
#'   working directory -- the project root, when you have opened the project's
#'   `.Rproj` -- or absolute. A folder is read whole, subfolders included. The
#'   originals are only ever read.
#' @param to Where the results go. Defaults to `data/` inside the working
#'   directory.
#' @param overwrite `FALSE` (the default) writes only what is missing from
#'   `to` or older than its original; `TRUE` rewrites the lot.
#' @param also Extensions to treat as already open for this call, with or
#'   without the dot, e.g. `"las"`. Permanently: add them to
#'   `.cd_open_formats` at the top of the project's `R/convert_data.R`.
#' @return The paths written, invisibly.
#' @export
#' @examples
#' src <- file.path(tempdir(), "originals")
#' dir.create(src, showWarnings = FALSE)
#' write.csv(head(iris), file.path(src, "iris.csv"), row.names = FALSE)
#' out <- file.path(tempdir(), "data")
#'
#' convert_data(src, to = out)   # copied: a .csv is already open
#' list.files(out)
#' unlink(c(src, out), recursive = TRUE)
#'
#' \dontrun{
#' # Inside a project, with the working directory at its root:
#' convert_data("originals/counts.xlsx")   # one workbook, one .csv per sheet
#' convert_data("originals")               # a whole folder
#' convert_data("~/Downloads/plots.gpkg")  # copied, not converted
#' convert_data("originals", also = "las") # teach it one more open format
#' }
convert_data <- function(path, to = NULL, overwrite = FALSE,
                         also = character(0)) {
  .cd_check_string(path, "path")
  if (!is.null(to)) .cd_check_string(to, "to")
  if (!is.logical(overwrite) || length(overwrite) != 1L || is.na(overwrite)) {
    stop("`overwrite` must be TRUE or FALSE.", call. = FALSE)
  }
  if (is.null(also)) also <- character(0)
  if (!is.character(also) || anyNA(also)) {
    stop("`also` must be a character vector of extensions, e.g. \"las\".",
         call. = FALSE)
  }

  root <- .cd_norm(getwd())
  from <- path.expand(path)
  if (!file.exists(from)) {
    stop("There is nothing at ", from, call. = FALSE)
  }
  from <- .cd_norm(from)
  to   <- if (is.null(to)) file.path(root, "data") else path.expand(to)
  if (!dir.exists(to)) dir.create(to, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(to)) stop("Could not create ", to, call. = FALSE)
  to <- .cd_norm(to)

  is_dir <- dir.exists(from)
  src <- if (is_dir) list.files(from, full.names = TRUE, recursive = TRUE) else from
  src <- src[!grepl("^[.]|[.]gitkeep$", basename(src))]
  # Files that are already in the destination have nowhere to go: this is what
  # stops convert_data("data") from copying the folder onto itself.
  src <- src[.cd_norm(dirname(src), mustWork = FALSE) != to]
  if (!length(src)) {
    message("Nothing to convert in ", path, ".")
    return(invisible(character(0)))
  }

  base <- if (is_dir) from else dirname(from)
  rel  <- substring(src, nchar(base) + 2L)   # as you see it, inside the source
  ext  <- tolower(tools::file_ext(src))
  open_ok <- unique(c(.cd_open_formats, tolower(sub("^[.]", "", also))))

  # The road each file takes: the package that converts it, "copy", or "skip".
  road <- rep("skip", length(src))
  road[ext %in% open_ok] <- "copy"
  conv <- ext %in% names(.cd_converters)
  road[conv] <- .cd_converters[ext[conv]]

  # One warning per missing package, naming the files it holds back, rather
  # than one warning per file.
  need   <- unique(road[conv])
  absent <- need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
  if (length(absent)) {
    held <- road %in% absent
    warning(paste(absent, collapse = " and "), " not installed, so ",
            sum(held), " file(s) were not converted: ",
            paste(rel[held], collapse = ", "), ". ", .cd_install(absent),
            call. = FALSE, immediate. = TRUE)
    road[held] <- "held"
  }

  ledger <- new.env(parent = emptyenv())
  ledger$claimed    <- character(0)   # name in data/ -> the original that owns it
  ledger$collisions <- character(0)
  ctx <- list(to = to, overwrite = overwrite, ledger = ledger)

  done <- Map(function(f, r, e, how) {
    switch(how,
           readxl = .cd_excel(f, r, ctx),
           haven  = .cd_haven(f, r, e, ctx),
           copy   = .cd_copy(f, r, ctx),
           character(0))
  }, src, rel, ext, road)
  written  <- as.character(unlist(done, use.names = FALSE))
  labelled <- basename(src)[road == "haven" & lengths(done) > 0L]
  skipped  <- rel[road == "skip"]

  .cd_report(written, skipped, labelled, ledger$collisions,
             where = .cd_relative(to, root), path = path)
  invisible(written)
}

# --- Helpers ---------------------------------------------------------------

#' A single, non-empty, non-missing string, or stop naming the argument.
#' @noRd
.cd_check_string <- function(x, what) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    stop("`", what, "` must be a single non-empty path.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Absolute, symlinks resolved, forward slashes on every platform: the only
#' form two paths can be compared in.
#' @noRd
.cd_norm <- function(p, mustWork = TRUE) {
  normalizePath(p, winslash = "/", mustWork = mustWork)
}

#' `to` as the user sees it: relative to the working directory when inside it.
#' A plain prefix test, not a regex, so a folder called `a+b (c)` is fine.
#' @noRd
.cd_relative <- function(to, root) {
  if (startsWith(to, paste0(root, "/"))) substring(to, nchar(root) + 2L) else to
}

#' @noRd
.cd_install <- function(pkgs) {
  if (length(pkgs) == 1L) return(sprintf('install.packages("%s")', pkgs))
  sprintf("install.packages(c(%s))", paste0('"', pkgs, '"', collapse = ", "))
}

#' Has `dest` already been made from `origin`? Then leave it alone: a file
#' corrected by hand stays as it is until the original changes.
#' @noRd
.cd_up_to_date <- function(dest, origin, overwrite) {
  !overwrite && file.exists(dest) && file.mtime(dest) >= file.mtime(origin)
}

#' Reserve a name in the destination. Everything lands flat, and two sheet
#' names can collapse to one file name, so two originals can want the same
#' one. The first keeps it and the rest are refused: overwriting would publish
#' one table under another's name, and the count of files written would still
#' look right. Refusing is the only version of this you can notice.
#' Case-insensitive, because the deposit has to unpack on any file system.
#' @noRd
.cd_claim <- function(ledger, out, origin) {
  key <- tolower(basename(out))
  if (key %in% names(ledger$claimed)) {
    ledger$collisions <- c(ledger$collisions,
                           sprintf("%s was kept; %s was refused -- both give %s",
                                   ledger$claimed[[key]], origin, basename(out)))
    return(FALSE)
  }
  ledger$claimed[[key]] <- origin
  TRUE
}

#' Read with `reader` and write the .csv. A file that cannot be read is named
#' and skipped rather than aborting the whole batch.
#' @noRd
.cd_write_csv <- function(reader, out, what) {
  d <- tryCatch(reader(), error = function(e) {
    warning(what, " could not be read, so it was not converted: ",
            conditionMessage(e), call. = FALSE, immediate. = TRUE)
    NULL
  })
  if (is.null(d)) return(character(0))
  utils::write.csv(d, out, row.names = FALSE, fileEncoding = "UTF-8")
  out
}

#' A workbook: one sheet, one .csv. The sheet name only enters the file name
#' when the workbook has more than one: a single-sheet file keeps its own.
#' @noRd
.cd_excel <- function(f, rel, ctx) {
  sheets <- tryCatch(readxl::excel_sheets(f), error = function(e) {
    warning(rel, " could not be read, so it was not converted: ",
            conditionMessage(e), call. = FALSE, immediate. = TRUE)
    character(0)
  })
  if (!length(sheets)) return(character(0))
  stem <- tools::file_path_sans_ext(basename(f))
  many <- length(sheets) > 1L
  outs <- file.path(ctx$to, paste0(
    if (many) paste(stem, make.names(sheets), sep = "_") else stem, ".csv"))
  whats <- if (many) sprintf("%s [%s]", rel, sheets) else rel
  as.character(unlist(Map(function(sheet, out, what) {
    if (!.cd_claim(ctx$ledger, out, what)) return(character(0))
    if (.cd_up_to_date(out, f, ctx$overwrite)) return(character(0))
    .cd_write_csv(function() readxl::read_excel(f, sheet = sheet), out, what)
  }, sheets, outs, whats), use.names = FALSE))
}

#' A statistical package file: one .csv. The values travel, the labels
#' cannot: a .csv has nowhere to put them.
#' @noRd
.cd_haven <- function(f, rel, ext, ctx) {
  out <- file.path(ctx$to, paste0(tools::file_path_sans_ext(basename(f)), ".csv"))
  if (!.cd_claim(ctx$ledger, out, rel)) return(character(0))
  if (.cd_up_to_date(out, f, ctx$overwrite)) return(character(0))
  read <- switch(ext, sav = haven::read_sav, dta = haven::read_dta,
                 sas7bdat = haven::read_sas)
  .cd_write_csv(function() haven::zap_labels(read(f)), out, rel)
}

#' Already the open version: it travels as it is. Re-writing it would only
#' risk the encoding, the decimal separator or, in a binary container, the
#' file itself.
#' @noRd
.cd_copy <- function(f, rel, ctx) {
  out <- file.path(ctx$to, basename(f))
  if (!.cd_claim(ctx$ledger, out, rel)) return(character(0))
  if (.cd_up_to_date(out, f, ctx$overwrite)) return(character(0))
  if (!file.copy(f, out, overwrite = TRUE)) {
    warning(rel, " could not be copied into ", ctx$to, ".",
            call. = FALSE, immediate. = TRUE)
    return(character(0))
  }
  out
}

#' What happened, on screen: the files written, then the three things worth
#' knowing -- a name refused, labels that did not travel, a file left behind.
#' @noRd
.cd_report <- function(written, skipped, labelled, collisions, where, path) {
  if (length(written)) {
    message(where, "/ updated: ", length(written), " file(s) -- ",
            paste(basename(written), collapse = ", "))
  } else {
    message(where, "/ is already up to date with ", path, ".")
  }
  if (length(collisions)) {
    warning("Two originals want the same name in ", where, "/, so only one ",
            "was written:\n  ",
            paste(collisions, collapse = "\n  "),
            "\n  Everything lands flat, subfolders included. Rename one of ",
            "them, or it will never reach the deposit.",
            call. = FALSE, immediate. = TRUE)
  }
  if (length(labelled)) {
    message("Converted from a labelled format: ",
            paste(labelled, collapse = ", "),
            "\n  The values travelled, the value and variable labels did not: ",
            "a .csv has nowhere to put them. The original keeps them, and ",
            "data/metadata/attributes.csv is where they belong in the deposit.")
  }
  if (length(skipped)) {
    message("Not a format this knows, left where it is: ",
            paste(skipped, collapse = ", "),
            "\n  They will not reach the deposit. If one of them is already an ",
            "open format, name its extension -- also = \"gpkg\" for one call, ",
            "or add it to .cd_open_formats at the top of R/convert_data.R for ",
            "good. If it is closed and nothing here converts it, export it ",
            "yourself and put the result in ", where, "/.")
  }
  invisible(NULL)
}
