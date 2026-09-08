# ---------------------------------------------------------------------------
# convert_data() -- originals in, open formats out.
#
# This file is the canonical copy. create_paper() writes an identical one into
# each project's R/, so a project keeps working with easypaper uninstalled.
# tests/testthat/test-convert_data.R checks the two never drift apart.
# ---------------------------------------------------------------------------

.cd_open_formats <- c(
  "csv", "tsv", "txt", "json", "geojson", "xml", "yml", "yaml",  # text
  "parquet", "nc", "h5", "hdf5", "sqlite", "db", "gpkg",         # containers
  "shp", "shx", "dbf", "prj", "cpg", "sbn", "sbx", "qix",        # a shapefile
  "kml", "gml", "tif", "tiff", "asc",                            # spatial
  "fasta", "fa", "fastq", "fq", "nwk", "tre"                     # sequences
)

.cd_absolute <- function(p) {
  grepl("^(/|~)", p) || grepl("^[A-Za-z]:[/\\\\]", p)
}

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
#'   to publish.
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
#' one table quietly overwriting another.
#'
#' @param path File or folder to read, relative to the working directory --
#'   the project root, when you have opened the project's `.Rproj` -- or an
#'   absolute path. A folder is read whole, subfolders included. The originals
#'   are only ever read.
#' @param to Where the results go. Defaults to `data/` beside the working
#'   directory.
#' @param overwrite `FALSE` (the default) writes only what is missing from
#'   `to` or older than its original; `TRUE` rewrites the lot.
#' @param also Extensions to treat as already open for this call, with or
#'   without the dot, e.g. `"las"`. Permanently: add them to
#'   `.cd_open_formats` at the top of the project's `R/convert_data.R`.
#' @return The paths written, invisibly.
#' @export
#' @examples
#' \dontrun{
#' convert_data("originals/counts.xlsx")   # one workbook, one .csv per sheet
#' convert_data("originals")               # a whole folder
#' convert_data("~/Downloads/plots.gpkg")  # copied, not converted
#' convert_data("originals", also = "las") # teach it one more open format
#' }
convert_data <- function(path, to = NULL, overwrite = FALSE,
                         also = character(0)) {
  root <- getwd()
  if (is.null(to)) to <- file.path(root, "data")
  from <- if (.cd_absolute(path)) path.expand(path) else file.path(root, path)

  if (!file.exists(from)) {
    stop("There is nothing at ", from, call. = FALSE)
  }
  dir.create(to, recursive = TRUE, showWarnings = FALSE)

  src <- if (dir.exists(from)) {
    list.files(from, full.names = TRUE, recursive = TRUE)
  } else {
    from
  }
  src <- src[!grepl("^[.]|[.]gitkeep$", basename(src))]
  # Files that are already in the destination have nowhere to go: this is what
  # stops convert_data("data") from copying the folder onto itself.
  dest_real <- normalizePath(to, mustWork = FALSE)
  src <- src[normalizePath(dirname(src), mustWork = FALSE) != dest_real]
  if (!length(src)) {
    message("Nothing to convert in ", path, ".")
    return(invisible(character(0)))
  }

  open_ok    <- unique(c(.cd_open_formats, tolower(sub("^[.]", "", also))))
  written    <- character(0)
  skipped    <- character(0)
  labelled   <- character(0)
  collisions <- character(0)
  claimed    <- character(0)   # name in data/ -> the original that owns it

  fresh <- function(dest, origin) {
    !overwrite && file.exists(dest) &&
      file.mtime(dest) >= file.mtime(origin)
  }

  # Everything lands flat, and two sheet names can collapse to one file name,
  # so two originals can want the same one. The first keeps it and the rest
  # are refused: overwriting would publish one table under another's name, and
  # the count of files written would still look right. Refusing is the only
  # version of this you can notice.
  claim <- function(out, origin) {
    key <- basename(out)
    if (key %in% names(claimed)) {
      collisions <<- c(collisions,
                       sprintf("%s was kept; %s was refused -- both give %s",
                               claimed[[key]], origin, key))
      return(FALSE)
    }
    claimed[[key]] <<- origin
    TRUE
  }

  base <- if (dir.exists(from)) from else dirname(from)
  for (f in src) {
    ext  <- tolower(tools::file_ext(f))
    stem <- tools::file_path_sans_ext(basename(f))
    rel  <- substring(f, nchar(base) + 2L)   # as you see it, inside the source

    if (ext %in% c("xlsx", "xls")) {
      if (!requireNamespace("readxl", quietly = TRUE)) {
        warning("readxl is not installed, so ", basename(f), " was not ",
                "converted. install.packages(\"readxl\")",
                call. = FALSE, immediate. = TRUE)
        next
      }
      sheets <- readxl::excel_sheets(f)
      for (s in sheets) {
        # One sheet, one .csv. The sheet name only enters the file name when
        # the workbook has more than one: a single-sheet file keeps its own.
        out <- file.path(to, paste0(
          if (length(sheets) > 1L) paste(stem, make.names(s), sep = "_") else stem,
          ".csv"))
        if (!claim(out, if (length(sheets) > 1L)
                          sprintf("%s [%s]", rel, s) else rel)) next
        if (fresh(out, f)) next
        d <- readxl::read_excel(f, sheet = s)
        utils::write.csv(d, out, row.names = FALSE, fileEncoding = "UTF-8")
        written <- c(written, out)
      }
    } else if (ext %in% c("sav", "dta", "sas7bdat")) {
      if (!requireNamespace("haven", quietly = TRUE)) {
        warning("haven is not installed, so ", basename(f), " was not ",
                "converted. install.packages(\"haven\")",
                call. = FALSE, immediate. = TRUE)
        next
      }
      out <- file.path(to, paste0(stem, ".csv"))
      if (!claim(out, rel)) next
      if (fresh(out, f)) next
      d <- switch(ext,
                  sav      = haven::read_sav(f),
                  dta      = haven::read_dta(f),
                  sas7bdat = haven::read_sas(f))
      # The values travel, the labels cannot: a .csv has nowhere to put them.
      utils::write.csv(haven::zap_labels(d), out, row.names = FALSE,
                       fileEncoding = "UTF-8")
      written  <- c(written, out)
      labelled <- c(labelled, basename(f))
    } else if (ext %in% open_ok) {
      # Already the open version: it travels as it is. Re-writing it would
      # only risk the encoding, the decimal separator or, in a binary
      # container, the file itself.
      out <- file.path(to, basename(f))
      if (!claim(out, rel)) next
      if (fresh(out, f)) next
      file.copy(f, out, overwrite = TRUE)
      written <- c(written, out)
    } else {
      # Neither convertible nor known to be open: a proprietary instrument
      # file, an ArcGIS project, a photograph of a field notebook. Nothing
      # here can tell whether it belongs in the paper, so it is named rather
      # than dropped in silence.
      skipped <- c(skipped, rel)
    }
  }

  where <- sub(paste0("^", root, "/"), "", to)
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
  invisible(written)
}
