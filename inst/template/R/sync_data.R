# ---------------------------------------------------------------------------
# Keeps data/csv/ in step with data/raw/.
#
# The originals in raw/ are never touched: this only reads them. Spreadsheets
# are converted sheet by sheet, and files that are already plain text are
# copied across unchanged -- because what publishes and what gets described is
# data/csv/, and a .csv sitting in raw/ would otherwise never reach the
# deposit. That silence is the reason this converts everything rather than the
# one file you remember to name.
#
# A format conversion, not a transformation: cleaning, filtering and recoding
# belong in the analysis chunk that needs them, where a reader can check them.
# ---------------------------------------------------------------------------

#' Convert or copy every original in data/raw/ into data/csv/.
#'
#' @param overwrite FALSE (the default) only writes a .csv that is missing or
#'   older than its original; TRUE rewrites the lot.
#' @return the paths written, invisibly.
sync_data <- function(overwrite = FALSE) {
  from <- here::here("data", "raw")
  to   <- here::here("data", "csv")
  dir.create(to, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(from)) {
    message("There is no data/raw/ to read from.")
    return(invisible(character(0)))
  }
  src <- list.files(from, full.names = TRUE, recursive = TRUE)
  src <- src[!grepl("^[.]|/[.]|[.]gitkeep$", basename(src))]
  if (!length(src)) {
    message("data/raw/ is empty: nothing to convert.")
    return(invisible(character(0)))
  }

  written <- character(0)
  skipped <- character(0)
  fresh <- function(dest, origin) {
    !overwrite && file.exists(dest) &&
      file.mtime(dest) >= file.mtime(origin)
  }

  for (f in src) {
    ext <- tolower(tools::file_ext(f))
    stem <- tools::file_path_sans_ext(basename(f))

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
        if (fresh(out, f)) next
        d <- readxl::read_excel(f, sheet = s)
        utils::write.csv(d, out, row.names = FALSE, fileEncoding = "UTF-8")
        written <- c(written, out)
      }
    } else if (ext %in% c("csv", "tsv", "txt")) {
      # Already plain text: it travels as it is. No re-writing, which would
      # only risk mangling the encoding or the decimal separator.
      out <- file.path(to, basename(f))
      if (fresh(out, f)) next
      file.copy(f, out, overwrite = TRUE)
      written <- c(written, out)
    } else {
      # A database, a GeoPackage, a NetCDF, a photograph of a field notebook:
      # not something to turn into a .csv. Some of them cannot be converted
      # without deciding what "the table" is -- a .sqlite has several and the
      # query that joins them -- and others should not be converted at all,
      # because a raster or a shapefile IS the open format. They are named at
      # the end rather than dropped in silence: leaving raw/ unnoticed is how a
      # compendium goes out without its data.
      skipped <- c(skipped, basename(f))
    }
  }

  if (length(written)) {
    message("data/csv/ updated: ", length(written), " file(s) -- ",
            paste(basename(written), collapse = ", "))
  } else {
    message("data/csv/ is already in step with data/raw/.")
  }
  if (length(skipped)) {
    message("Left in data/raw/, not a format this converts: ",
            paste(skipped, collapse = ", "),
            "\n  They will not reach the deposit. If they should be published, ",
            "put a copy in data/csv/ yourself: an open format travels as it is ",
            "-- a .sqlite, a GeoPackage, a NetCDF -- and nothing here will ",
            "touch it again.")
  }
  invisible(written)
}
