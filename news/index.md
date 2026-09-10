# Changelog

## easypaper 0.2.1

Everything here reaches a project already written through
[`update_project()`](https://danielsangarci.github.io/easypaper/reference/update_project.md),
except the two files it never touches: `R/setup.R`, which carries the
table fix, and `_sections/`. Copy those two by hand, or start the
project again.

### Tables in the .docx match the .pdf

- A table built with flextable came out misaligned in Word and correct
  in the PDF, from the same code. `fit_flextable_to_page()` stretched
  every table to exactly 6 inches, and Quarto wraps each captioned table
  in a container 5.5 inches wide: a 6 inch table inside a 5.5 inch cell
  is what pushed the columns out of line. LaTeX sizes columns from their
  content and ignored the ask, which is why only the `.docx` was wrong.
- **A table now keeps the width
  [`flextable::autofit()`](https://davidgohel.github.io/flextable/reference/autofit.html)
  gives it** and is never stretched to fill the line, so
  `flextable(x) |> autofit()` and `fit_flextable_to_page()` produce the
  same table. The helper adds one thing: a table too wide for the page
  is scaled back to 5.5 inches instead of running off it. `pgwidth` sets
  that ceiling.
- The worked example in `_sections/7_tables.qmd` now shows the table a
  journal actually asks for: no rule on top, one under the header row
  and one under the table, the significance stars added to the `p`
  column as a suffix so the column stays a number, and the legend of
  those stars as a footer line. It is written as a pipeline, which is
  how you will extend it.

### One output folder

- A render used to sort its results into `output/journal/`,
  `output/preprint/` and `output/supplementary/`. **Everything now lands
  flat in `output/`**: the journal `.docx`, the preprint `.pdf`, the
  supplement or supplements, `analysis_code.R`, `sessionInfo.txt` and
  the copy of `renv.lock`. One folder, because you open it to find a
  document, not to navigate. `submission/` is untouched: what a journal
  or a repository receives is still laid out the way each of them asks
  for.
- A render no longer fails when `output/` is missing. The folders were
  created once, when `make.R` was sourced, and every render then trusted
  them to still be there – so deleting `output/`, which the project’s
  own README calls safe, broke the next render in an open session, and
  did it with a message about a temporary file instead of a missing
  folder. The folder is now created at the moment of writing.
- [`update_project()`](https://danielsangarci.github.io/easypaper/reference/update_project.md)
  names the old subfolders when a project still has them. It never
  deletes anything; everything under `output/` is regenerable.

### split = TRUE writes the supplement too

- `render_docx(split = TRUE)` and `render_pdf(split = TRUE)` wrote the
  main text alone. The supplement was rendered only when it was about to
  be merged back in, so asking for the two files a journal wants gave
  you one, in silence, while `run.R` and the guide both promised two.
  **The supplement is now rendered either way**, one document per
  `_sections/8*suppl*.qmd`, into `output/supplementary/`; `split`
  decides only whether the two are then put back together. With
  `suppl_figures = "main"` the floats stay in the main text and only the
  supplementary *text* comes out on its own, as before.
- `make_submission()` and `make_preprint()` render the supplement
  themselves, with their own subset of files and their own labelled
  names, so they now pass `supplement = FALSE` and still render it
  exactly once.

### The blinded manuscript carries its title

- `make_submission()` built `main_*.docx` with the whole title block
  removed, so the anonymised manuscript opened straight at the Abstract.
  **The title now stays**, at the head of the document and in the same
  Word style the title page uses; a journal expects to see it there, and
  it identifies nobody. What is removed is what does identify you: the
  author block, the affiliations and the correspondence line, plus the
  date. `title_*.docx` is unchanged, and `blinded = FALSE` still keeps
  the whole block, authors included.

### Quieter renders

- A render no longer prints
  `incomplete final line found by readTableHeader`.
  `dataspice::create_spice()` writes its scaffold without a final
  newline, and `sync_metadata()` read it with
  [`read.csv()`](https://rdrr.io/r/utils/read.table.html), which warned
  about that on every render until the file had been written back once.
  The four metadata files are now read through a helper that muffles
  exactly that warning and no other; your own data files are read as
  before, because a malformed line in one of those is worth hearing
  about.
- A first render no longer dumps renv’s whole resolved library, a
  hundred lines of it, over the log. `.record_env()` wrapped the
  snapshot in
  [`suppressMessages()`](https://rdrr.io/r/base/message.html), but renv
  prints straight to the console rather than through
  [`message()`](https://rdrr.io/r/base/message.html), so nothing was
  ever caught. Both snapshot sites now set renv’s own switch for it. The
  lockfile is written exactly as before, and the one line that says so
  is still printed.

### Fixed

- `.gitignore` ignored `tmp_supplementary_S*.qmd` but not the `.docx` or
  `.pdf` of the same name, so a render that failed halfway left an
  untracked file behind in the repository. It now covers
  `tmp_supplementary_S*`.

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

### update_project() and add_journal()

- **[`update_project()`](https://danielsangarci.github.io/easypaper/reference/update_project.md)**
  brings a project written by an earlier version up to the installed
  one. The build logic a project carries – `make.R`, `run.R`,
  `R/submission.R`, `R/convert_data.R`, the Word templates, the `.csl`
  files the template ships – is refreshed from the package; what you
  wrote – `_sections/`, the YAML, `_quarto.yml`, `references/`, `data/`,
  `R/setup.R` – is never touched, and nothing is ever deleted.
  `dry_run = TRUE` lists what would change. It insists on a clean git
  working tree, so the update is one commit you can read with `git diff`
  and revert file by file; without a repository it keeps the replaced
  files under [`tempdir()`](https://rdrr.io/r/base/tempfile.html) for
  the session. Open formats you had added to `R/convert_data.R` are
  named so you can put them back, and the steps a version leaves to you
  – for 0.2.0, the move from `data/csv/` to `data/` – are printed when
  the project needs them. The stamp at the top of `make.R` then records
  both versions: the one that created the project and the one it was
  updated to.
- **[`add_journal()`](https://danielsangarci.github.io/easypaper/reference/add_journal.md)**
  fetches any journal’s citation style from the official CSL repository
  into `references_styles/`, where `render_docx("<journal>")` and
  `make_submission("<journal>")` find it. Most journals’ styles are
  dependent – a pointer at a parent whose rules they share – and pandoc
  cannot follow the pointer, so the parent’s rules are what lands in the
  project, under the name you asked for. Base R downloads the file and
  checks it is a style; nothing new is installed, and a local checkout
  of the repository works offline.

### Hardened

- Every argument of
  [`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md)
  and
  [`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
  is checked before anything is written: a `path` that is not one
  string, a `title` that is not text, a flag that is not `TRUE` or
  `FALSE`, stop with a message naming the argument and leave no
  half-made project behind. A `path` that exists as a file is refused
  rather than written into, and `open = TRUE` outside RStudio says so
  instead of doing nothing.
- A title with a backslash – a LaTeX fragment, say – or a double quote
  reached the YAML unescaped and broke it, and a title given as a vector
  wrote a broken header with a warning. Titles and author names are now
  escaped for YAML, and a vector is joined into one title.
- [`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md)
  looked for `title:` and `author:` anywhere in the file, and assumed
  the author block was followed by another key. A line of prose starting
  with `title:`, or an author list at the end of the header, would have
  corrupted the file. Both keys are now replaced inside the YAML fences
  only. The project also takes its name from the resolved path, so `"."`
  and a trailing slash give the `.Rproj` its real name.
- [`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md):
  a working directory with a regex character in its name (`+`, `(`, a
  dot) broke the closing message. A workbook or a `.sav` that cannot be
  read is now named and skipped instead of aborting the batch, a copy
  that fails is reported instead of counted as written, a missing readxl
  or haven is reported once per call instead of once per file, and two
  names that differ only in case count as a collision, because the
  deposit has to unpack on a file system that cannot tell them apart.

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
