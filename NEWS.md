# easypaper 0.3.2

Documentation only: no code changes. `update_project()` refreshes `run.R`,
`make.R`, `R/submission.R` and the project `README.md`, which is where these
corrections land in a project already written.

## The examples say what the arguments now do

* `make_submission("myrmecological-news", label = "MyrmecologicalNews")` was
  still the headline example for `label`, and since 0.3.0 **it does nothing**:
  that is exactly what the call produces on its own. Every example now passes
  `label = "MyrmecologicalNews_v2"`, which is what the argument is actually
  for -- a second version of the same submission, landing in
  `submission/MyrmecologicalNews_v2/` beside the first.
* `create_paper()` is shown with `title = "Manuscript title here"`, the same
  placeholder the template writes, so what you read in the example is what you
  find in `manuscript.qmd`. The example authors are `"First Author"` and
  `"Second Author"` for the same reason.

# easypaper 0.3.1

One defect, and everything it was dragging behind it. `update_project()`
carries the fix into a project already written: it is a change to
`R/submission.R`, which is one of the files it refreshes.

## The supplement is rendered the way the rest of the project is

* The standalone supplement came out **with the R code of every chunk printed
  above its own figure**, as if the reader had asked to see it. The manuscript
  never did this, which is what made it look like a quirk of the supplement.
* It is not. The document Quarto renders for a supplement is a wrapper written
  on the fly, and a wrapper is not in the `render:` list of `_quarto.yml`:
  Quarto reads it as a loose file and **nothing in the project configuration
  reaches it**. The bibliography and the journal were already being handed over
  by hand; how the chunks run was not, so the supplement fell back on Quarto's
  own defaults, where `echo` is true.
* The `execute:` and `knitr:` blocks of `_quarto.yml` are now copied into that
  wrapper, so the supplement comes out of the same press as the paper.
  Anything `supplementary.qmd` sets for itself still wins.
* **Two more things were riding on that same fault.** Supplementary figures
  were written at Quarto's 96 dpi instead of the 600 the project asks for, and
  into the temporary directory Quarto deletes after a `.docx` render -- so
  `figures/png/` never saw them and `export_figure_formats()` had nothing to
  convert. They now land beside the manuscript's own figures and get their
  `.jpg` and `.tiff` copies like everything else. Expect new files under
  `figures/` after the first render: they are the supplementary ones, and they
  are what a journal asks for on acceptance.
* The title page is a loose file of the same kind. It carries no chunks in the
  template, so nothing was wrong with it, but a project that works its word
  count out on that page would have had the same code printed above its title.
  Its render now carries the project's execution settings too.

# easypaper 0.3.0

`update_project()` carries this into a project already written: it is
a change to `R/submission.R`, which is one of the files it refreshes.

## The manuscript says which journal, and the call can still override it

* A `csl:` was declared in `_quarto.yml`, and **the functions ignored it**,
  carrying a default of their own. The same project gave you two different
  journals depending on how you asked: the RStudio Render button used the
  `.csl` in `_quarto.yml`, `make_submission()` used `"myrmecological-news"`.
  They agreed only until you changed one of them.
* **The journal is now declared in the manuscript's YAML**, beside its title,
  its authors and its keywords, which is where the rest of what this paper is
  already lives. `journal` defaults to `NULL`, meaning "the one the manuscript
  names", so `render_docx()`, `make_all()` and `make_submission()` all go
  there with no argument to repeat. A `csl:` in `_quarto.yml` still works and
  is read as a fallback; the manuscript wins, which is Quarto's own order.
* Naming one in a call still wins over both, for that call, and changes no
  file: `make_submission("ecology-letters")`.
* Neither available raises an error that lists the styles you have, instead of
  quietly picking one.
* It survives an update: `manuscript.qmd` and `_quarto.yml` are both files
  `update_project()` never touches.

## Naming the journal names everything

* `label` is what the submission folder and every file in it are called, and
  it defaulted to `"default"`. **Left alone it is now built from the journal's
  own name**, spaces taken out: `make_submission("ecology-letters")` lands in
  `submission/EcologyLetters/` with `main_EcologyLetters.docx` inside it. One
  argument, the `.csl`, now names the whole submission.
* The argument stays, for when you want to name a submission yourself:
  `label = "Journal1"`, `label = "Revision2"`, whatever tells the folders
  apart. What you pass names the files and nothing else; the letter and the
  checklist always carry the journal's real name.

## The cover letter knows which journal it is addressed to

* It was handed the `label`, not the journal, so a trial run produced a
  letter offering the manuscript *for consideration in default* and a
  checklist headed *Submission checklist -- default*. The label names the
  folder and the files and is meant to read like that; the letter is not.
* **Both now take the journal's own name**, read from its `.csl` the same
  way the supplement's reference does: `"ecology-letters"` reaches the
  page as *Ecology Letters*. The files are still named after the label.

# easypaper 0.2.4

Two defects that only Word saw. `update_project()` carries the fix
into a project already written: it refreshes `make.R`,
`R/submission.R` and the three Word templates, which is everything
this release touches.

## Word opens the .docx

* Word refused every document that had a table in it: *"Word found unreadable
  content"*, and what it offered to recover opened read-only. LibreOffice,
  Google Docs and Pages read the same file without a word, which is what made
  this possible to ship unnoticed.
* The cause is the shape Quarto gives a captioned float: a one-cell table with
  the flextable inside it, so the cell **ends with a table**. The OOXML schema
  requires the last thing in a cell to be a paragraph. **Every `.docx` a render
  produces is now repaired before it is handed over**: one empty paragraph
  before each such cell closes. A document that does not need it comes back
  untouched.
* That same container declared 100% of the text width and then fixed its grid
  at pandoc's own default of 5.5 inches, whatever the page was. A figure is
  sized to the text width, so a 6.5-inch figure went into a 5.5-inch cell. The
  grid is now set to the width the page really has.
* The `Table` style of the three Word templates no longer reserves a margin
  inside each cell, which was another tenth of an inch taken off the width a
  figure had to fit in.
* **A figure is no longer clipped down its right edge.** The paragraph that
  holds it inherited the body text's first-line indent, half an inch, and a
  figure is drawn as wide as the text column: the indent pushed that half inch
  past the right margin and Word cut it off. The repair resets the indent on
  any paragraph that holds a figure.

# easypaper 0.2.3

`update_project()` carries all of this into a project already written. What
it never touches is `R/setup.R` and `_sections/`, so the manuscript's own
sections and the two table examples are what you copy across by hand.

## Placeholders that read as instructions

* A new project opened on `TITLE HERE`, `First Author name` and
  `keyword 1`. Now it opens on **`Manuscript title here`, `Author1`,
  `Author2` and `keyword1`**: shorter, unmistakably yours to replace, and
  numbered the way you will number the affiliations. `make.R` still warns
  while the author placeholders are in the YAML, and a test now ties its list
  to what the template actually ships, so the two cannot drift.

## A title page with nothing blank on it

* The page carried six bold labels with nothing after them -- running head,
  keywords, word count, figure and table counts, ORCID, funding -- which is
  what a title page reaches a journal looking like when nobody fills it in.
  **They are gone.** What is left is the title, the authors, the affiliations
  and the sections a blinded submission moves across.
* **The keywords are a section of the manuscript now**, right after the
  abstract, so they travel in `main_*.docx` and in every render. They are
  still written once, in the `keywords:` of the YAML, which is also where the
  deposit's metadata reads them: the section prints that list rather than
  repeating it.

## The title page and the main text share one set of sections

* The title page listed its own fields as bold labels ending in a colon --
  `**Acknowledgements:**`, `**CRediT authorship contribution statement:**` --
  while the manuscript carried sections of the same meaning under proper
  headings. Two names for one thing, and a colon where a heading should be.
  **The page now uses the manuscript's own headings**, so a submission is
  built out of the same sections a render shows.
* **A blinded submission moves four sections onto the title page** rather
  than repeating them: Acknowledgements, the CRediT statement, the conflict of
  interest statement and the data availability statement come out of
  `main_*.docx` and appear on `title_*.docx`, in that order, carrying the text
  you wrote in the manuscript. Everything else stays in the main text. With
  `blinded = FALSE` they stay where they were and the title page does not
  repeat them.
* Which sections these are is `BLINDED_SECTIONS`, at the top of
  `R/submission.R`, for the journal that draws the line somewhere else.

## A supplement that says which paper it belongs to

* The supplement opened with the manuscript's bare title under its own. It now
  opens with **a reference to the paper**: authors, title and journal, in the
  shape a reference takes. That file is downloaded on its own from a journal's
  site, with nothing around it to say what it supports.
* The authors are written the way a reference writes them: **`Lovelace, A.,
  Turing, A.`**, family name first and given names as initials. The last word
  of a name is taken as the family name, so write a name with a particle you
  want kept the way you want it read.
* The journal's name is read from its own `.csl`, so `"myrmecological-news"`
  reaches the page as *Myrmecological News*. A style with no title falls back
  to the file name.
* **The affiliations and the correspondence line are gone from the
  supplement.** The reference above says whose paper it is; underneath it they
  were an address on a document that is not a letter.
* A blinded submission's supplement drops the authors from that reference and
  keeps the title and the journal.

## No date, and a supplement that says who wrote it

* A rendered manuscript no longer carries a date. It was `today`, so every
  render stamped the document with the day you happened to run it, which on a
  draft you circulate is worse than nothing: a manuscript is dated by the
  journal. Put `date: today` back in `manuscript.qmd` if you want one.
* **The supplement now names its authors**, under the title and above the
  affiliations, which is where a reader looks for them. It carried the
  affiliations and no names at all.
* **And a blinded submission's supplement carries neither.** It used to travel
  with the affiliations and the correspondence line in it, which name you as
  surely as the names do: the main text was anonymised and the document beside
  it was not. `render_supplementary()` takes `blinded` for this, and
  `make_submission()` passes its own through. `make_preprint()` signs both, as
  it always did.

# easypaper 0.2.2

## One document per section, and no merging

* `render_docx()` and `render_pdf()` joined the manuscript and its supplement
  into a single file unless you passed `split = TRUE`. Making that file means
  handing both documents to pandoc, which rebuilds them instead of copying:
  the rebuilt tables reach Word **with their column widths gone and every
  heading broken across two lines**. `Variable` came out as `Variab / le`.
  **The merge is gone and so is `split`.** Each render writes one document per
  section into `output/`, each with its own reference list, which is also the
  shape a journal asks for. `qpdf` is no longer needed.

## Every table is a flextable, and nothing draws a bar around it

* The example tables used two engines, and `knitr::kable()` was the weaker of
  the two: pandoc gives a markdown table columns of equal width without
  measuring anything, so a long heading was broken over two lines while a
  short one sat in acres of space. It also came out in the document's own font
  while the flextable came out in Times New Roman. **Every table in the
  template is a flextable now**, with the same font, the same rules and
  columns measured from their content.
* The three Word templates drew a thick rule above and below **every table and
  figure**. It came from the `Table` style, which Quarto applies to the
  container it wraps each captioned float in, so the bars had nothing to do
  with the table inside. That style no longer draws borders; a flextable draws
  its own.

# easypaper 0.2.1

Everything here reaches a project already written through
`update_project()`, except the two files it never touches:
`R/setup.R`, which carries the table fix, and `_sections/`.
Copy those two by hand, or start the project again.

## Tables in the .docx match the .pdf

* A table built with flextable came out misaligned in Word and correct in the
  PDF, from the same code. `fit_flextable_to_page()` stretched every table to
  exactly 6 inches, and Quarto wraps each captioned table in a container 5.5
  inches wide: a 6 inch table inside a 5.5 inch cell is what pushed the
  columns out of line. LaTeX sizes columns from their content and ignored the
  ask, which is why only the `.docx` was wrong.
* **A table now keeps the width `flextable::autofit()` gives it** and is never
  stretched to fill the line, so `flextable(x) |> autofit()` and
  `fit_flextable_to_page()` produce the same table. The helper adds one thing:
  a table too wide for the page is scaled back to 5.5 inches instead of
  running off it. `pgwidth` sets that ceiling.
* The worked example in `_sections/7_tables.qmd` now shows the table a journal
  actually asks for: no rule on top, one under the header row and one under
  the table, the significance stars added to the `p` column as a suffix so the
  column stays a number, and the legend of those stars as a footer line. It is
  written as a pipeline, which is how you will extend it.

## One output folder

* A render used to sort its results into `output/journal/`,
  `output/preprint/` and `output/supplementary/`. **Everything now lands flat
  in `output/`**: the journal `.docx`, the preprint `.pdf`, the supplement or
  supplements, `analysis_code.R`, `sessionInfo.txt` and the copy of
  `renv.lock`. One folder, because you open it to find a document, not to
  navigate. `submission/` is untouched: what a journal or a repository
  receives is still laid out the way each of them asks for.
* A render no longer fails when `output/` is missing. The folders were created
  once, when `make.R` was sourced, and every render then trusted them to still
  be there -- so deleting `output/`, which the project's own README calls safe,
  broke the next render in an open session, and did it with a message about a
  temporary file instead of a missing folder. The folder is now created at the
  moment of writing.
* `update_project()` names the old subfolders when a project still has them.
  It never deletes anything; everything under `output/` is regenerable.

## split = TRUE writes the supplement too

* `render_docx(split = TRUE)` and `render_pdf(split = TRUE)` wrote the main
  text alone. The supplement was rendered only when it was about to be merged
  back in, so asking for the two files a journal wants gave you one, in
  silence, while `run.R` and the guide both promised two. **The supplement is
  now rendered either way**, one document per `_sections/8*suppl*.qmd`, into
  `output/supplementary/`; `split` decides only whether the two are then put
  back together. With `suppl_figures = "main"` the floats stay in the main
  text and only the supplementary *text* comes out on its own, as before.
* `make_submission()` and `make_preprint()` render the supplement themselves,
  with their own subset of files and their own labelled names, so they now
  pass `supplement = FALSE` and still render it exactly once.

## The blinded manuscript carries its title

* `make_submission()` built `main_*.docx` with the whole title block removed,
  so the anonymised manuscript opened straight at the Abstract. **The title
  now stays**, at the head of the document and in the same Word style the
  title page uses; a journal expects to see it there, and it identifies
  nobody. What is removed is what does identify you: the author block, the
  affiliations and the correspondence line, plus the date. `title_*.docx` is
  unchanged, and `blinded = FALSE` still keeps the whole block, authors
  included.

## Quieter renders

* A render no longer prints `incomplete final line found by readTableHeader`.
  `dataspice::create_spice()` writes its scaffold without a final newline, and
  `sync_metadata()` read it with `read.csv()`, which warned about that on
  every render until the file had been written back once. The four metadata
  files are now read through a helper that muffles exactly that warning and no
  other; your own data files are read as before, because a malformed line in
  one of those is worth hearing about.
* A first render no longer dumps renv's whole resolved library, a hundred
  lines of it, over the log. `.record_env()` wrapped the snapshot in
  `suppressMessages()`, but renv prints straight to the console rather than
  through `message()`, so nothing was ever caught. Both snapshot sites now set
  renv's own switch for it. The lockfile is written exactly as before, and the
  one line that says so is still printed.

## Fixed
* `.gitignore` ignored `tmp_supplementary_S*.qmd` but not the `.docx` or
  `.pdf` of the same name, so a render that failed halfway left an untracked
  file behind in the repository. It now covers `tmp_supplementary_S*`.

# easypaper 0.2.0

## One data folder

* A project used to carry `data/raw/` and `data/csv/`: the originals in one,
  their converted copies in the other. **There is now a single `data/`**, and
  it is the folder that publishes -- what the analysis reads, what the
  metadata describes and what the deposit carries. `data/metadata/` stays
  where it was, beside it.
* Your originals live wherever you keep them. The project no longer prescribes
  a place, because it never published them: a `.xlsx` in `data/raw/` was an
  archive copy that travelled nowhere, and every `.csv` in there existed twice
  in the repository for no gain.
* **Migrating a project written by 0.1.0**: move the contents of `data/csv/`
  up into `data/` and delete the empty folder; move `data/raw/` wherever you
  want your originals to live, inside the project or outside it; and change
  the paths the analysis reads from `data/csv/...` to `data/...`.

## convert_data(), replacing sync_data()

* `sync_data()` kept two folders in step. Nothing is in step any more, so the
  function is **`convert_data(path)`**: you name an original -- a file or a
  whole folder, relative to the working directory or absolute -- and it lands
  in `data/`, converted or copied. It never runs by itself and it never moves,
  edits or converts an original in place.
* It is **exported by the package**, so `easypaper::convert_data()` works in
  any project, and `create_paper()` writes the identical file into the
  project's `R/` so a project keeps working with easypaper uninstalled. A test
  checks the two copies never drift apart.
* Every file takes one of three roads: **converted** (`.xlsx`, `.xls` through
  readxl; `.sav`, `.dta`, `.sas7bdat` through haven), **copied byte for byte**
  when it already is an open format, or **named on screen** when it is
  neither. The copy list is `.cd_open_formats` at the top of the file -- plain
  text, `.json`, `.parquet`, `.nc`, `.h5`, `.sqlite`, `.gpkg`, a `.shp` with
  all its sidecars, `.tif`, `.fasta` and more -- and it is a list you can
  edit, because the file lives in your project. `also = "las"` extends it for
  a single call. Before this, a GeoPackage or a NetCDF was named and left
  behind even though it needed no conversion at all.
* Two originals that would land on the same name no longer overwrite each
  other silently. Everything lands flat, so `a/counts.csv` and `b/counts.csv`
  -- or two sheets whose names differ only in a character a file name cannot
  hold -- used to collapse into one, with the count of files written still
  looking right. One keeps the name, the rest are refused, and a warning says
  which was which.
* Converting a labelled `.sav` or `.dta` says so: the values travel, the value
  and variable labels do not, and `data/metadata/attributes.csv` is where they
  belong in the deposit.

## update_project() and add_journal()

* **`update_project()`** brings a project written by an earlier version up to
  the installed one. The build logic a project carries -- `make.R`, `run.R`,
  `R/submission.R`, `R/convert_data.R`, the Word templates, the `.csl` files
  the template ships -- is refreshed from the package; what you wrote --
  `_sections/`, the YAML, `_quarto.yml`, `references/`, `data/`, `R/setup.R`
  -- is never touched, and nothing is ever deleted. `dry_run = TRUE` lists
  what would change. It insists on a clean git working tree, so the update
  is one commit you can read with `git diff` and revert file by file;
  without a repository it keeps the replaced files under `tempdir()` for the
  session. Open formats you had added to `R/convert_data.R` are named so you
  can put them back, and the steps a version leaves to you -- for 0.2.0, the
  move from `data/csv/` to `data/` -- are printed when the project needs
  them. The stamp at the top of `make.R` then records both versions: the one
  that created the project and the one it was updated to.
* **`add_journal()`** fetches any journal's citation style from the official
  CSL repository into `references_styles/`, where `render_docx("<journal>")`
  and `make_submission("<journal>")` find it. Most journals' styles are
  dependent -- a pointer at a parent whose rules they share -- and pandoc
  cannot follow the pointer, so the parent's rules are what lands in the
  project, under the name you asked for. Base R downloads the file and checks
  it is a style; nothing new is installed, and a local checkout of the
  repository works offline.

## Hardened

* Every argument of `create_paper()` and `convert_data()` is checked before
  anything is written: a `path` that is not one string, a `title` that is not
  text, a flag that is not `TRUE` or `FALSE`, stop with a message naming the
  argument and leave no half-made project behind. A `path` that exists as a
  file is refused rather than written into, and `open = TRUE` outside RStudio
  says so instead of doing nothing.
* A title with a backslash -- a LaTeX fragment, say -- or a double quote
  reached the YAML unescaped and broke it, and a title given as a vector
  wrote a broken header with a warning. Titles and author names are now
  escaped for YAML, and a vector is joined into one title.
* `create_paper()` looked for `title:` and `author:` anywhere in the file, and
  assumed the author block was followed by another key. A line of prose
  starting with `title:`, or an author list at the end of the header, would
  have corrupted the file. Both keys are now replaced inside the YAML fences
  only. The project also takes its name from the resolved path, so `"."` and
  a trailing slash give the `.Rproj` its real name.
* `convert_data()`: a working directory with a regex character in its name
  (`+`, `(`, a dot) broke the closing message. A workbook or a `.sav` that
  cannot be read is now named and skipped instead of aborting the batch, a
  copy that fails is reported instead of counted as written, a missing readxl
  or haven is reported once per call instead of once per file, and two names
  that differ only in case count as a collision, because the deposit has to
  unpack on a file system that cannot tell them apart.

## Fixed

* `source("make.R")` now defines the data function. It did not, so the second
  line of the quickstart failed with "could not find function".
* `check_data()` no longer reports the sidecars of a shapefile as unread. The
  code only ever names the `.shp`; its `.dbf`, `.shx` and `.prj` are the same
  dataset. It also ignores `data/metadata/`, which describes the data rather
  than being data.
* Two stale paths in the project's own documentation: the submission checklist
  and the deposit tree pointed at a `data/csv/` subfolder inside
  `data_and_code/`, which the compendium has never created -- it flattens the
  data into `data_and_code/data/`.
* The deposit's README no longer promises that the data are `.csv`: it can now
  carry any open format.

# easypaper 0.1.0

First version.

* `create_paper()` writes the full structure of a reproducible Quarto
  manuscript: sections as separate files, `make.R` as the single entry point,
  journal styles, Word templates, and the folders for data, figures and
  outputs.
* Optional `title` and `authors`, written into the YAML of `manuscript.qmd`
  and into the title page.
* Initialises a git repository and makes the first commit (`git = TRUE`),
  skipping it with a clear message when git is absent or has no identity
  configured.
* The top of the project's `make.R` records which version of easypaper wrote
  the structure. The project never needs the package again; the stamp is what
  tells you, later, which version produced a project you already have.
* Also available from RStudio as **File > New Project > New Directory >
  Reproducible Quarto manuscript**.
