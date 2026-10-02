# easypaper 0.1.0

First release.

## A project that holds only the paper

* `create_paper()` writes a Quarto project for one manuscript: the text in
  `_sections/`, one file per section, the references and the journal's
  citation style in `references/`, the setup of the analysis in `R/setup.R`
  and the data in `data/`. The build logic lives in the package, so a fix
  reaches every project with `update.packages()`. Also in RStudio, under
  *File > New Project*.
* `create_example_paper()` writes the same project with a small study in it
  -- the trees of Barro Colorado Island -- to see how each part is written.
* Authors and affiliations are written in the YAML of `manuscript.qmd`, the
  way Quarto documents them; every render numbers the affiliations and prints
  the authors on one line, as a paper does (`affiliations()`).
* A short title in the YAML is printed under the title of every document
  but the preprint, and counted.
* Settings go in the `easypaper:` block of `_quarto.yml`, so they travel with
  the paper.

## Data

* `convert_data()` brings originals into `data/` in open formats: workbooks
  and statistical files become `.csv`, files already open are copied, and the
  originals are only ever read.
* `sync_metadata()` describes the data deposit from what the project already
  knows, and `edit_metadata()` opens an editor for the rest.

## Rendering

* `render_html()`, `render_docx()`, `render_pdf()` and
  `render_supplementary()` write documents to read into `output/`, in the
  style of the journal the manuscript names or of any other; `render_all()`
  runs `render_docx()`, `render_pdf()` and `export_code()` in one go.
  `preview()` reloads as you save.
* The supplement is a document of its own, with its own reference list and
  its own numbering: *Figure S1*, *Table S1*.
* Figures are exported at 600 dpi as PNG, JPEG and TIFF on every render.
* Captions follow the `crossref:` block of `_quarto.yml`, or a caption style
  for one render: `"abbrev"`, `"colon"`, `"compact"`, `"nature"`, or one of
  your own.
* `list_journals()` and `add_journal()` manage the citation styles, fetched
  from the official CSL repository.

## Checks

* Every render checks citations, cross-references, packages, data files, the
  title and `renv.lock` first (`?checks`), and records the environment it
  came out of.
* Every render sets the scientific names of the reference list in italics,
  checked against GBIF; `italicize_species()` does it for any bibliography,
  and `check_species()` lists the names left in doubt.
* `check_species_text()` reads the text the way an editor does: italics,
  first mention, abbreviation, authority.
* `manuscript_stats()` gives what a submission form asks for: characters of
  the title, words of the abstract and the main text, references, figures
  and tables. Every render prints it.

## Submitting

* `make_submission()` builds the folder for a journal into `submission/`:
  double-blind by default, with a title page and a main text that names
  nobody, figures renumbered at 600 dpi, a cover letter, a checklist, and a
  data and code compendium -- with a copy for the reviewers that names nobody
  either. `blind = FALSE` for a signed manuscript.
* `make_preprint()` builds the preprint: one signed PDF and its supplement,
  with the same compendium.
* `deposit_zenodo()` reserves the DOI of the data on Zenodo and writes it
  into the text, without publishing.

## Co-authors

* `td_upload()`, `td_download()` and `td_update()` share a section with
  co-authors in Google Docs, through trackdown.
