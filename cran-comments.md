## Resubmission

This is a resubmission. Thank you for the review. In this version:

* The single quotes around the acronyms CSL and GBIF in the Description are
  gone; they remain only around the names of software ('Quarto', 'renv',
  'easypaper').
* No example has code commented out. The examples of `italicize_species()`
  and of the renders now run code instead, on files and projects in
  `tempdir()`.
* `\dontrun{}` is kept only where the example cannot be executed by the
  user without something the package cannot provide:
  * Quarto, a separate program (in `SystemRequirements`), which the renders
    and `make_submission()` / `make_preprint()` run, and which writes caches
    of its own in the user's home: `render_html()`, `render_docx()`,
    `render_pdf()`, `render_supplementary()`, `render_all()`, `preview()`,
    `make_submission()`, `make_preprint()`. Their examples create the
    project in `tempdir()` and run; only the call to Quarto is in
    `\dontrun{}`.
  * An account or an API key: `td_upload()`, `td_update()` and
    `td_download()` need a Google account; `deposit_zenodo()` needs a Zenodo
    token and creates a deposit on Zenodo.
  Every other example runs: the ones of `create_paper()`,
  `create_example_paper()`, `convert_data()` and `add_journal()` that were
  in `\dontrun{}` are replaced by examples on `tempdir()` (`convert_data()`
  converts `readxl::readxl_example("datasets.xlsx")`), and the interactive
  editors of `edit_metadata()` are wrapped in `if (interactive())`.
* Nothing is written by default in the user's home filespace or in the
  working directory:
  * No function has a default path any more: `path = NULL`. Given a `path`,
    a function works on the project there. Without one, a function that
    writes refuses to in a non-interactive session, and in an interactive
    one it asks for confirmation before writing into the project the
    working directory is in -- once a session, with `utils::menu()`,
    naming the folder -- as the CRAN policy allows. Only the functions that
    merely read (`check_citations()`, `list_journals()`,
    `manuscript_stats()`...) use that project without asking.
  * `convert_data()` writes into a project's `data/` under the same rule,
    and outside a project requires `to`.
  * `italicize_species()` requires `output`; it no longer writes beside its
    input by default.
  * The examples, the tests and the vignette write only to `tempdir()`.

  Asking once a session is meant to keep the package practical while
  following the policy: the user works inside the project of the paper the
  whole time, calling `render_all()` or `make_submission()` there again and
  again, so a single confirmation spares giving `path` in every call.
  easypaper writes only into a folder that is an easypaper project (holding
  `_quarto.yml` and `manuscript.qmd`, as created by `create_paper()`), never
  into an arbitrary working directory or the home filespace; anywhere else,
  it stops.
* No function installs packages: `create_example_paper()` no longer offers
  to install vegan (in `Suggests`); it stops and says what to install.
* `installed.packages()` is no longer used; the base packages are listed.

Besides the points of the review, this version fixes defects and adds a few
features found since the first submission, so that you know everything that
changed:

* Fixed: the description of the data deposit read every `.csv` as
  comma-separated, so a `;`-separated one (what spreadsheets write in a
  language with a decimal comma) came out as one column, and it read images
  as tables. Tables are now read with their own separator, `.tsv` included,
  and every other file is described by its kind and size.
* Fixed: Greek letters typed in the text were missing from the PDF, whose
  LaTeX font has none; they are now taken from the maths font, with nothing
  to install.
* Fixed: citing a supplementary figure by its number alone, `-@sfig-x`,
  printed "1" instead of "S1".
* Fixed: the supplement of a preprint named a journal; it now names the
  preprint server.
* New: the text can cite figures and tables with another word than their
  caption's ("Figure 1." in the caption, "Fig. 1" in the text), through the
  `crossref:` block of `_quarto.yml` or a caption style.
* New: `make_submission()` and `make_preprint()` take `figure_dpi`, the
  resolution of the figures for that call (600 dpi by default, from
  `_quarto.yml`, no longer fixed), and name each standalone figure with its
  resolution and printed size.
* Layout of the documents: the PDF sets its title block flush left, with an
  ORCID icon beside each author (drawn with TikZ, nothing to install), and
  justifies the captions; the supplement opens with "Supporting Information"
  over the reference of the paper, flush left, in the PDF and in the Word
  document, whose captions are justified too.

## Test environments

* local macOS 27 (aarch64), R 4.5.0
* win-builder: Windows, R-devel (2026-10-14 r90673 ucrt)
* GitHub Actions: Ubuntu (R-devel, R-release, R-oldrel-1), macOS
  (R-release), Windows (R-release)

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release. The only note, on win-builder, is "New
  submission", with CSL and GBIF as possibly misspelled words in the
  DESCRIPTION: they are the acronyms of the Citation Style Language and of
  the Global Biodiversity Information Facility, now without quotes as the
  review asked. GitHub Actions returns no note.

## Notes for the reviewer

* The package drives Quarto, a separate program, through the quarto package:
  it is declared in `SystemRequirements`. Nothing that needs it runs on
  CRAN: the tests that render skip there, and the code chunks of the
  vignette are not evaluated.
* `italicize_species()` queries the GBIF and Wikipedia APIs. Without a
  connection it does not fail: the names it could not check are left in roman
  and a warning says so. Its examples and tests do not use the network. The
  answers are cached in `tools::R_user_dir("easypaper", "cache")` unless the
  user gives another location; inside a project, in the project.
