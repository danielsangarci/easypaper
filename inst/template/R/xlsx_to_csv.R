# ---------------------------------------------------------------------------
# Conversion of the original .xlsx files to .csv (open, versionable, citable
# format). The .xlsx live in data/raw/ and are never touched; the generated
# .csv go to data/processed/.
# ---------------------------------------------------------------------------
library(here)
library(readxl)

#' @param filename name of the .xlsx inside data/raw/
#' @param sheet    sheet name or index
#' @param out      name of the .csv in data/processed/ (defaults to the sheet)
xlsx_to_csv <- function(filename, sheet = 1, out = NULL) {
  input <- here("data/raw", filename)
  if (!file.exists(input)) stop("Does not exist: ", input)

  df <- readxl::read_excel(input, sheet = sheet)

  if (is.null(out)) {
    out <- paste0(if (is.character(sheet)) sheet else tools::file_path_sans_ext(filename),
                  ".csv")
  }
  dest <- here("data/processed", out)
  utils::write.csv(df, dest, row.names = FALSE, fileEncoding = "UTF-8")
  message("Written: ", dest, " (", nrow(df), " rows x ", ncol(df), " columns)")
  invisible(dest)
}

## Usage:
# xlsx_to_csv("behaviour.xlsx", sheet = "adoption_experiment")
