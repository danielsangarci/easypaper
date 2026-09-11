# Convert or copy originals into the project's data folder

The project publishes what is in `data/`: the analysis reads it, the
metadata describes it and the submission compendium carries it. This
brings an original into that folder in a format that will still open in
twenty years. It never writes anywhere else and never touches the
original.

## Usage

``` r
convert_data(path, to = NULL, overwrite = FALSE, also = character(0))
```

## Arguments

- path:

  File or folder to read, as a single string: relative to the working
  directory – the project root, when you have opened the project's
  `.Rproj` – or absolute. A folder is read whole, subfolders included.
  The originals are only ever read.

- to:

  Where the results go. Defaults to `data/` inside the working
  directory.

- overwrite:

  `FALSE` (the default) writes only what is missing from `to` or older
  than its original; `TRUE` rewrites the lot.

- also:

  Extensions to treat as already open for this call, with or without the
  dot, e.g. `"las"`. Permanently: add them to `.cd_open_formats` at the
  top of the project's `R/convert_data.R`.

## Value

The paths written, invisibly.

## Details

Each file takes one of three roads, decided by its extension alone:

- **Converted** to `.csv`: `.xlsx` and `.xls`, one `.csv` per sheet
  (needs readxl); `.sav`, `.dta` and `.sas7bdat`, one `.csv` per file
  (needs haven). These are closed formats with an open equivalent
  faithful enough to publish. A file that cannot be read – corrupt, or
  not really what its extension says – is named in a warning and
  skipped, and the rest of the batch goes on. A missing readxl or haven
  is reported once per call, with the files it held back.

- **Copied byte for byte**, because they already are the open format and
  converting one would destroy it rather than open it:

  - text and tables: `.csv`, `.tsv`, `.txt`, `.json`, `.geojson`,
    `.xml`, `.yml`, `.yaml`

  - containers: `.parquet`, `.nc`, `.h5`, `.hdf5`, `.sqlite`, `.db`,
    `.gpkg`

  - spatial: `.shp` with its sidecars (`.shx`, `.dbf`, `.prj`, `.cpg`,
    `.sbn`, `.sbx`, `.qix`), `.kml`, `.gml`, `.tif`, `.tiff`, `.asc`

  - sequences and trees: `.fasta`, `.fa`, `.fastq`, `.fq`, `.nwk`,
    `.tre`

- **Named on screen and left where it is**: anything else. A proprietary
  instrument file, an ArcGIS project, a photograph of a field notebook –
  nothing here can tell whether it belongs in the paper, or what "the
  table" inside it would even be.

That second list is `.cd_open_formats`, at the top of this file. Print
it to see what is in it, add to it when your field uses something it has
not heard of, or pass the extension in `also` for a single call. The
file lives in your project, so the list is yours to edit.

A format conversion, not a transformation: filtering, recoding and
cleaning belong in the analysis chunk that needs them, where a reader
can check them. Every conversion costs something – an `.xlsx` loses its
formulas, an `.sav` its value labels – which is why the original is
never moved or altered.

Subfolders of a source folder are read but not reproduced: everything
lands flat in `data/`. When two originals want the same name there, one
keeps it – whichever comes first in alphabetical order by path – and the
rest are refused with a warning saying which was kept and which was not,
rather than one table quietly overwriting another. Names that differ
only in case count as the same name, because the deposit has to unpack
on a file system that cannot tell `Counts.csv` from `counts.csv`.

## Examples

``` r
src <- file.path(tempdir(), "originals")
dir.create(src, showWarnings = FALSE)
write.csv(head(iris), file.path(src, "iris.csv"), row.names = FALSE)
out <- file.path(tempdir(), "data")

convert_data(src, to = out)   # copied: a .csv is already open
#> /tmp/RtmpkEkVsd/data/ updated: 1 file(s) -- iris.csv
list.files(out)
#> [1] "iris.csv"
unlink(c(src, out), recursive = TRUE)

if (FALSE) { # \dontrun{
# Inside a project, with the working directory at its root:
convert_data("originals/counts.xlsx")   # one workbook, one .csv per sheet
convert_data("originals")               # a whole folder
convert_data("~/Downloads/plots.gpkg")  # copied, not converted
convert_data("originals", also = "las") # teach it one more open format
} # }
```
