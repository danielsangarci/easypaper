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
* Every function works on the project you name: once a session with
  `set_paper(".")`, or in a call with `path`. One that writes never takes the
  working directory for the project: with none named, it stops before
  writing. One that only reads takes the working directory's project when
  none is named.
* The project's `README.md`, what a repository shows first, carries the title,
  the authors with their affiliations and ORCID, the keywords and the licence
  notice from the first commit, and the DOI of the data once it is reserved;
  every render keeps them in step with `manuscript.qmd`.

## Data

* `convert_data()` brings originals into `data/` in open formats: workbooks
  and statistical files become `.csv`, files already open are copied, and the
  originals are only ever read. Outside a project, `to` says where the
  results go.
* `sync_metadata()` describes the data deposit from what the project already
  knows -- the title, the keywords, the authors with their affiliations,
  the email of the corresponding author and their ORCID, the licence of the
  data from the project's `LICENSE`, every file of `data/`, and the
  variables of each table, read with its own separator (`,`, `;` or a tab)
  -- and `edit_metadata()` opens an editor for the rest. `make_preprint()` and
  `make_submission()` compile it into `dataspice.json` and its page before
  they build the compendium, so the deposit describes the data as they are.

## Rendering

* `render_html()`, `render_docx()`, `render_pdf()` and
  `render_supplementary()` write documents to read into `output/`, in the
  style of the journal the manuscript names or of any other; `render_all()`
  runs `render_docx()`, `render_pdf()` and `export_code()` in one go.
  `preview()` reloads as you save. Every document is named after the
  project, `manuscript_<project>.docx`, with the journal added when it is
  not the manuscript's own.
* The main text has its lines numbered, in the `.docx` and in the `.pdf`.
  The affiliations and the keywords line start without the first-line
  indent of the text.
* The supplement is a document of its own, with its own reference list and
  its own numbering: *Figure S1*, *Table S1*; `-@sfig-x` cites the number
  alone, *S1*. It opens with "Supporting Information" and, under it, the
  reference of the paper, flush left; a preprint's names the server instead
  of a journal. One that cites nothing has no reference list.
* Figures are exported as PNG, JPEG and TIFF on every render, at the `dpi` of
  `_quarto.yml` (600 in a new project).
* The `.pdf` sets the title block flush left, with an ORCID icon beside each
  author who has one, justifies the captions, and prints the Greek letters
  of the text, which LaTeX's font lacks.
* `export_code()` writes the code of every chunk into one script,
  `analysis_code.R`, that opens with a table of contents: the line each
  section starts on and the chunks it holds. Each analysis lives in the
  results section that reports it, so each is found under its own heading.
* Captions follow the `crossref:` block of `_quarto.yml`, or a caption style
  for one render: `"abbrev"`, `"colon"`, `"compact"`, `"nature"`, or one of
  your own. The text may cite with another word than the caption's: *Figure
  1.* under the figure, *Fig. 1* in the text.
* `list_journals()` and `add_journal()` manage the citation styles, fetched
  from the official CSL repository.
* A new project cites easypaper and renv in the last paragraph of its
  Methods, ready to keep.
* `write_packages_bib()` writes the references of the R packages the
  manuscript uses, as `knitr::write_bib()` does, with the names in their
  titles kept as written: *vegan: Community ecology package*, not *Vegan*,
  in a journal that sets titles in sentence case.

## Checks

* Every render checks citations, cross-references, packages, data files and
  the title first (`?checks`), and records the environment it came out of in
  `renv.lock`; `check_renv()` says whether that record matches the library.
* Every render sets the scientific names of the reference list in italics,
  checked against GBIF; `italicize_species()` does it for any bibliography,
  into the CSL-JSON file you name, and `check_species()` lists the names left
  in doubt.
* `check_species_text()` reads the text the way an editor does: italics,
  first mention, abbreviation, authority.
* `manuscript_stats()` gives what a submission form asks for: characters of
  the title, words of the abstract and the main text, references, figures
  and tables. Every render prints it.

## Submitting

* `make_submission()` builds the folder for a journal into `submission/`:
  double-blind by default, with a title page and a main text that names
  nobody, standalone figures renumbered and named with their resolution and
  printed size (`Figure_1_600dpi_180x120mm.tiff`; `figure_dpi` changes the
  resolution for one call), a cover letter already dated,
  titled and signed by the corresponding author -- written from the last
  one, with those brought up to date, when the paper goes to a second
  journal -- a checklist, and a
  data and code compendium -- with a copy for the reviewers that names nobody
  either. `blind = FALSE` for a signed manuscript.
* `make_preprint()` builds the preprint: one signed PDF and its supplement,
  with the same compendium.
* A submission is never overwritten: a second `make_submission()` or
  `make_preprint()` to the same journal or server builds the next version
  beside the first, `JournalofEcology_v2`, with its files named the same
  way.
* `deposit_zenodo()` reserves the DOI of the data on Zenodo and writes it
  into the text and the cover letters, without publishing. The deposit
  carries the licence of the project's `LICENSE`, as the data's metadata do;
  an ORCID iD Zenodo could not read is left out of it, with a warning.

## Co-authors

* `td_upload()`, `td_download()` and `td_update()` share a section with
  co-authors in Google Docs, through trackdown.
