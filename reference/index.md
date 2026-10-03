# Package index

## Creating a project

The project holds the paper; everything below builds it.

- [`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md)
  : Create a reproducible Quarto manuscript project
- [`create_example_paper()`](https://danielsangarci.github.io/easypaper/reference/create_example_paper.md)
  : Create an example project: a small study, written as an easypaper
  paper
- [`affiliations()`](https://danielsangarci.github.io/easypaper/reference/affiliations.md)
  : The affiliations of the manuscript, under the authors

## Rendering

Documents to read, written into output/. Every render checks the project
first, sets the scientific names of the references in italics, and
copies the figures to PNG, JPEG and TIFF at 600 dpi.

- [`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md)
  [`render_pdf()`](https://danielsangarci.github.io/easypaper/reference/render.md)
  [`render_html()`](https://danielsangarci.github.io/easypaper/reference/render.md)
  [`render_supplementary()`](https://danielsangarci.github.io/easypaper/reference/render.md)
  [`render_all()`](https://danielsangarci.github.io/easypaper/reference/render.md)
  [`preview()`](https://danielsangarci.github.io/easypaper/reference/render.md)
  : Render the manuscript
- [`export_code()`](https://danielsangarci.github.io/easypaper/reference/export_code.md)
  : Write the analysis code as one script
- [`export_figure_formats()`](https://danielsangarci.github.io/easypaper/reference/export_figure_formats.md)
  : Copy every figure to JPEG and TIFF at 600 dpi
- [`clean_cache()`](https://danielsangarci.github.io/easypaper/reference/clean_cache.md)
  : Clear the knitr cache

## Submitting

What you send, built into submission/: the manuscript split for
double-blind review, the supplement, the figures, and the data and code
compendium.

- [`make_preprint()`](https://danielsangarci.github.io/easypaper/reference/make_preprint.md)
  : Build a preprint deposit
- [`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
  : Build the folder you send to a journal

## Checking

What every render verifies first, to call on its own.

- [`check_citations()`](https://danielsangarci.github.io/easypaper/reference/checks.md)
  [`check_crossrefs()`](https://danielsangarci.github.io/easypaper/reference/checks.md)
  [`check_packages()`](https://danielsangarci.github.io/easypaper/reference/checks.md)
  [`check_title()`](https://danielsangarci.github.io/easypaper/reference/checks.md)
  [`check_data()`](https://danielsangarci.github.io/easypaper/reference/checks.md)
  [`check_renv()`](https://danielsangarci.github.io/easypaper/reference/checks.md)
  : Check a project before rendering it
- [`check_species()`](https://danielsangarci.github.io/easypaper/reference/check_species.md)
  : Which scientific names of the references go in italics
- [`check_species_text()`](https://danielsangarci.github.io/easypaper/reference/check_species_text.md)
  : Check the scientific names in the text
- [`manuscript_stats()`](https://danielsangarci.github.io/easypaper/reference/manuscript_stats.md)
  : A summary of the manuscript

## Data and metadata

data/ is the folder that publishes. convert_data() brings originals in,
in a format that will still open in twenty years; the deposit’s metadata
is filled in from what the project already knows.

- [`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
  : Convert or copy originals into the project's data folder
- [`deposit_zenodo()`](https://danielsangarci.github.io/easypaper/reference/deposit_zenodo.md)
  : Reserve the DOI of the data deposit on Zenodo
- [`sync_metadata()`](https://danielsangarci.github.io/easypaper/reference/sync_metadata.md)
  : Fill in what the data deposit's metadata can know by itself
- [`edit_metadata()`](https://danielsangarci.github.io/easypaper/reference/edit_metadata.md)
  : Describe the data deposit by hand
- [`sync_licenses()`](https://danielsangarci.github.io/easypaper/reference/sync_licenses.md)
  : Copy the authors into the licences

## Journals and references

Any journal’s citation style, fetched from the official CSL repository
into references/; and the scientific names of any bibliography in
italics.

- [`list_journals()`](https://danielsangarci.github.io/easypaper/reference/list_journals.md)
  : The journals a project can render for
- [`add_journal()`](https://danielsangarci.github.io/easypaper/reference/add_journal.md)
  : Add a journal's citation style to the project
- [`italicize_species()`](https://danielsangarci.github.io/easypaper/reference/italicize_species.md)
  : Set the scientific names of a bibliography in italics

## Co-authors in Google Docs

- [`td_upload()`](https://danielsangarci.github.io/easypaper/reference/trackdown.md)
  [`td_update()`](https://danielsangarci.github.io/easypaper/reference/trackdown.md)
  [`td_download()`](https://danielsangarci.github.io/easypaper/reference/trackdown.md)
  : Edit a section with co-authors in Google Docs

## Package

- [`easypaper`](https://danielsangarci.github.io/easypaper/reference/easypaper-package.md)
  [`easypaper-package`](https://danielsangarci.github.io/easypaper/reference/easypaper-package.md)
  : easypaper: automate reproducible Quarto manuscripts from draft to
  submission
