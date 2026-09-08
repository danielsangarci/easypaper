# Changelog

## easypaper 0.2.0

### One data folder

- A project used to carry `data/raw/` and `data/csv/`: the originals in
  one, their converted copies in the other. **There is now a single
  `data/`**, and it is the folder that publishes – what the analysis
  reads, what the metadata describes and what the deposit carries.
  `data/metadata/` stays where it was, beside it.
- Your originals live wherever you keep them. The project no longer
  prescribes a place, because it never published them: a `.xlsx` in
  `data/raw/` was an archive copy that travelled nowhere, and every
  `.csv` in there existed twice in the repository for no gain.
- **Migrating a project written by 0.1.0**: move the contents of
  `data/csv/` up into `data/` and delete the empty folder; move
  `data/raw/` wherever you want your originals to live, inside the
  project or outside it; and change the paths the analysis reads from
  `data/csv/...` to `data/...`.

### convert_data(), replacing sync_data()

- `sync_data()` kept two folders in step. Nothing is in step any more,
  so the function is **`convert_data(path)`**: you name an original – a
  file or a whole folder, relative to the working directory or absolute
  – and it lands in `data/`, converted or copied. It never runs by
  itself and it never moves, edits or converts an original in place.
- It is **exported by the package**, so
  [`easypaper::convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
  works in any project, and
  [`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md)
  writes the identical file into the project’s `R/` so a project keeps
  working with easypaper uninstalled. A test checks the two copies never
  drift apart.
- Every file takes one of three roads: **converted** (`.xlsx`, `.xls`
  through readxl; `.sav`, `.dta`, `.sas7bdat` through haven), **copied
  byte for byte** when it already is an open format, or **named on
  screen** when it is neither. The copy list is `.cd_open_formats` at
  the top of the file – plain text, `.json`, `.parquet`, `.nc`, `.h5`,
  `.sqlite`, `.gpkg`, a `.shp` with all its sidecars, `.tif`, `.fasta`
  and more – and it is a list you can edit, because the file lives in
  your project. `also = "las"` extends it for a single call. Before
  this, a GeoPackage or a NetCDF was named and left behind even though
  it needed no conversion at all.
- Two originals that would land on the same name no longer overwrite
  each other silently. Everything lands flat, so `a/counts.csv` and
  `b/counts.csv` – or two sheets whose names differ only in a character
  a file name cannot hold – used to collapse into one, with the count of
  files written still looking right. One keeps the name, the rest are
  refused, and a warning says which was which.
- Converting a labelled `.sav` or `.dta` says so: the values travel, the
  value and variable labels do not, and `data/metadata/attributes.csv`
  is where they belong in the deposit.

### Fixed

- `source("make.R")` now defines the data function. It did not, so the
  second line of the quickstart failed with “could not find function”.
- `check_data()` no longer reports the sidecars of a shapefile as
  unread. The code only ever names the `.shp`; its `.dbf`, `.shx` and
  `.prj` are the same dataset. It also ignores `data/metadata/`, which
  describes the data rather than being data.
- Two stale paths in the project’s own documentation: the submission
  checklist and the deposit tree pointed at a `data/csv/` subfolder
  inside `data_and_code/`, which the compendium has never created – it
  flattens the data into `data_and_code/data/`.
- The deposit’s README no longer promises that the data are `.csv`: it
  can now carry any open format.

## easypaper 0.1.0

First version.

- [`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md)
  writes the full structure of a reproducible Quarto manuscript:
  sections as separate files, `make.R` as the single entry point,
  journal styles, Word templates, and the folders for data, figures and
  outputs.
- Optional `title` and `authors`, written into the YAML of
  `manuscript.qmd` and into the title page.
- Initialises a git repository and makes the first commit
  (`git = TRUE`), skipping it with a clear message when git is absent or
  has no identity configured.
- The top of the project’s `make.R` records which version of easypaper
  wrote the structure. The project never needs the package again; the
  stamp is what tells you, later, which version produced a project you
  already have.
- Also available from RStudio as **File \> New Project \> New Directory
  \> Reproducible Quarto manuscript**.
