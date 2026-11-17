# Changelog

## easypaper (development version)

### Rendering

- Quarto is found where RStudio, Positron or Quarto’s installer put it,
  also from `Rscript` or a terminal, where it is not on the PATH,
  together with the pandoc it ships. It has to be 1.7 or later.
- The title in the properties of a `.docx` (File \> Properties) no
  longer carries the short title.
- Without a connection to GBIF, a call warns once, not once per
  document. The template and the worked example ship the answers their
  references need, so their first render sets the italics offline.

### Checks

- [`check_renv()`](https://danielsangarci.github.io/easypaper/reference/checks.md)
  compares `renv.lock` with the library in use, package by package, and
  names what differs.
- [`manuscript_stats()`](https://danielsangarci.github.io/easypaper/reference/manuscript_stats.md)
  finds the abstract and the reference list under the names journals
  give them – Summary, Literature cited – or under the ones
  `abstract-heading:` and `references-heading:` name in `_quarto.yml`.
- [`check_species()`](https://danielsangarci.github.io/easypaper/reference/check_species.md)
  says in its help that it writes the cache of names.

### Submitting

- A double-blind submission is read back for the authors’ names, emails,
  ORCID, affiliations and accounts, and what the text itself still says
  is reported, file by file. A reference that would name them – their
  own software, their own data paper – is left out of it when
  `blinded-drop-keys:` in `_quarto.yml` lists it.
- The compendium carries a `renv.lock` of its analysis alone: the
  packages it loads and what they need, without easypaper, which built
  the documents and is recorded in the project’s own. In the worked
  example, 68 packages instead of 118.

### Data

- The page of the metadata draws the area the data cover as a map inside
  it, with dataspice 1.2.1 and sf, maps and base64enc; without them it
  has no map. It never loads one from the internet, and opens offline.
  The worked example says where its data come from, the 50-ha plot of
  Barro Colorado Island.

### The worked example

- Species richness is modelled with a quasi-Poisson GLM, tested with an
  *F* test, and the PERMANOVA and PERMDISP permute plots only within
  five spatial blocks of contiguous plots. The Methods say what this
  allows for and what it does not.

### Other

- The next steps
  [`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md)
  and
  [`create_example_paper()`](https://danielsangarci.github.io/easypaper/reference/create_example_paper.md)
  print name `set_paper(".")`.
- [`td_upload()`](https://danielsangarci.github.io/easypaper/reference/trackdown.md),
  [`td_update()`](https://danielsangarci.github.io/easypaper/reference/trackdown.md)
  and
  [`td_download()`](https://danielsangarci.github.io/easypaper/reference/trackdown.md)
  are marked experimental: they need a trackdown that is not on CRAN.
- A code of conduct and a guide to contributing.

## easypaper 0.1.0

CRAN release: 2026-11-13

First release.

### A project that holds only the paper

- [`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md)
  writes a Quarto project for one manuscript: the text in `_sections/`,
  one file per section, the references and the journal’s citation style
  in `references/`, the setup of the analysis in `R/setup.R` and the
  data in `data/`. The build logic lives in the package, so a fix
  reaches every project with
  [`update.packages()`](https://rdrr.io/r/utils/update.packages.html).
  Also in RStudio, under *File \> New Project*.
- [`create_example_paper()`](https://danielsangarci.github.io/easypaper/reference/create_example_paper.md)
  writes the same project with a small study in it – the trees of Barro
  Colorado Island – to see how each part is written.
- Authors and affiliations are written in the YAML of `manuscript.qmd`,
  the way Quarto documents them; every render numbers the affiliations
  and prints the authors on one line, as a paper does
  ([`affiliations()`](https://danielsangarci.github.io/easypaper/reference/affiliations.md)).
- A short title in the YAML is printed under the title of every document
  but the preprint, and counted.
- Settings go in the `easypaper:` block of `_quarto.yml`, so they travel
  with the paper.
- Every function works on the project you name: once a session with
  `set_paper(".")`, or in a call with `path`. One that writes never
  takes the working directory for the project: with none named, it stops
  before writing. One that only reads takes the working directory’s
  project when none is named.
- The project’s `README.md`, what a repository shows first, carries the
  title, the authors with their affiliations and ORCID, the keywords and
  the licence notice from the first commit, and the DOI of the data once
  it is reserved; every render keeps them in step with `manuscript.qmd`.

### Data

- [`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
  brings originals into `data/` in open formats: workbooks and
  statistical files become `.csv`, files already open are copied, and
  the originals are only ever read. Outside a project, `to` says where
  the results go.
- [`sync_metadata()`](https://danielsangarci.github.io/easypaper/reference/sync_metadata.md)
  describes the data deposit from what the project already knows – the
  title, the keywords, the authors with their affiliations, the email of
  the corresponding author and their ORCID, the licence of the data from
  the project’s `LICENSE`, every file of `data/`, and the variables of
  each table, read with its own separator (`,`, `;` or a tab) – and
  [`edit_metadata()`](https://danielsangarci.github.io/easypaper/reference/edit_metadata.md)
  opens an editor for the rest.
  [`make_preprint()`](https://danielsangarci.github.io/easypaper/reference/make_preprint.md)
  and
  [`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
  compile it into `dataspice.json` and its page before they build the
  compendium, so the deposit describes the data as they are.

### Rendering

- [`render_html()`](https://danielsangarci.github.io/easypaper/reference/render.md),
  [`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md),
  [`render_pdf()`](https://danielsangarci.github.io/easypaper/reference/render.md)
  and
  [`render_supplementary()`](https://danielsangarci.github.io/easypaper/reference/render.md)
  write documents to read into `output/`, in the style of the journal
  the manuscript names or of any other;
  [`render_all()`](https://danielsangarci.github.io/easypaper/reference/render.md)
  runs
  [`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md),
  [`render_pdf()`](https://danielsangarci.github.io/easypaper/reference/render.md)
  and
  [`export_code()`](https://danielsangarci.github.io/easypaper/reference/export_code.md)
  in one go.
  [`preview()`](https://danielsangarci.github.io/easypaper/reference/render.md)
  reloads as you save. Every document is named after the project,
  `manuscript_<project>.docx`, with the journal added when it is not the
  manuscript’s own.
- The main text has its lines numbered, in the `.docx` and in the
  `.pdf`. The affiliations and the keywords line start without the
  first-line indent of the text.
- The supplement is a document of its own, with its own reference list
  and its own numbering: *Figure S1*, *Table S1*; `-@sfig-x` cites the
  number alone, *S1*. It opens with “Supporting Information” and, under
  it, the reference of the paper, flush left; a preprint’s names the
  server instead of a journal. One that cites nothing has no reference
  list.
- Figures are exported as PNG, JPEG and TIFF on every render, at the
  `dpi` of `_quarto.yml` (600 in a new project).
- The `.pdf` sets the title block flush left, with an ORCID icon beside
  each author who has one, justifies the captions, and prints the Greek
  letters of the text, which LaTeX’s font lacks.
- [`export_code()`](https://danielsangarci.github.io/easypaper/reference/export_code.md)
  writes the code of every chunk into one script, `analysis_code.R`,
  that opens with a table of contents: the line each section starts on
  and the chunks it holds. Each analysis lives in the results section
  that reports it, so each is found under its own heading.
- Captions follow the `crossref:` block of `_quarto.yml`, or a caption
  style for one render: `"abbrev"`, `"colon"`, `"compact"`, `"nature"`,
  or one of your own. The text may cite with another word than the
  caption’s: *Figure 1.* under the figure, *Fig. 1* in the text.
- [`list_journals()`](https://danielsangarci.github.io/easypaper/reference/list_journals.md)
  and
  [`add_journal()`](https://danielsangarci.github.io/easypaper/reference/add_journal.md)
  manage the citation styles, fetched from the official CSL repository.
- A new project cites easypaper and renv in the last paragraph of its
  Methods, ready to keep.
- [`write_packages_bib()`](https://danielsangarci.github.io/easypaper/reference/write_packages_bib.md)
  writes the references of the R packages the manuscript uses, as
  [`knitr::write_bib()`](https://rdrr.io/pkg/knitr/man/write_bib.html)
  does, with the names in their titles kept as written: *vegan:
  Community ecology package*, not *Vegan*, in a journal that sets titles
  in sentence case.

### Checks

- Every render checks citations, cross-references, packages, data files
  and the title first
  ([`?checks`](https://danielsangarci.github.io/easypaper/reference/checks.md)),
  and records the environment it came out of in `renv.lock`;
  [`check_renv()`](https://danielsangarci.github.io/easypaper/reference/checks.md)
  says whether that record matches the library.
- Every render sets the scientific names of the reference list in
  italics, checked against GBIF;
  [`italicize_species()`](https://danielsangarci.github.io/easypaper/reference/italicize_species.md)
  does it for any bibliography, into the CSL-JSON file you name, and
  [`check_species()`](https://danielsangarci.github.io/easypaper/reference/check_species.md)
  lists the names left in doubt.
- [`check_species_text()`](https://danielsangarci.github.io/easypaper/reference/check_species_text.md)
  reads the text the way an editor does: italics, first mention,
  abbreviation, authority.
- [`manuscript_stats()`](https://danielsangarci.github.io/easypaper/reference/manuscript_stats.md)
  gives what a submission form asks for: characters of the title, words
  of the abstract and the main text, references, figures and tables.
  Every render prints it.

### Submitting

- [`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
  builds the folder for a journal into `submission/`: double-blind by
  default, with a title page and a main text that names nobody,
  standalone figures renumbered and named with their resolution and
  printed size (`Figure_1_600dpi_180x120mm.tiff`; `figure_dpi` changes
  the resolution for one call), a cover letter already dated, titled and
  signed by the corresponding author – written from the last one, with
  those brought up to date, when the paper goes to a second journal – a
  checklist, and a data and code compendium – with a copy for the
  reviewers that names nobody either. `blind = FALSE` for a signed
  manuscript.
- [`make_preprint()`](https://danielsangarci.github.io/easypaper/reference/make_preprint.md)
  builds the preprint: one signed PDF and its supplement, with the same
  compendium.
- A submission is never overwritten: a second
  [`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
  or
  [`make_preprint()`](https://danielsangarci.github.io/easypaper/reference/make_preprint.md)
  to the same journal or server builds the next version beside the
  first, `JournalofEcology_v2`, with its files named the same way.
- [`deposit_zenodo()`](https://danielsangarci.github.io/easypaper/reference/deposit_zenodo.md)
  reserves the DOI of the data on Zenodo and writes it into the text and
  the cover letters, without publishing. The deposit carries the licence
  of the project’s `LICENSE`, as the data’s metadata do; an ORCID iD
  Zenodo could not read is left out of it, with a warning.

### Co-authors

- [`td_upload()`](https://danielsangarci.github.io/easypaper/reference/trackdown.md),
  [`td_download()`](https://danielsangarci.github.io/easypaper/reference/trackdown.md)
  and
  [`td_update()`](https://danielsangarci.github.io/easypaper/reference/trackdown.md)
  share a section with co-authors in Google Docs, through trackdown.
