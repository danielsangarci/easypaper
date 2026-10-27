## Resubmission

This is a second resubmission. Thank you for the review, which still saw
functions writing by default, e.g. in `convert_data()`. In this version no
function has a default path to write into, and none asks for confirmation
any more:

* A function that writes into a project writes only into the one the user
  names: in the call, with `path`, or once a session with the new
  `set_paper()`, which takes the folder and has no default
  (`set_paper(".")` from the project's folder). With neither, it stops
  before writing anything, interactive session or not. The working
  directory is never taken for the place to write.
* `convert_data()` writes into `to`; without `to`, into the `data/` folder
  of the project `set_paper()` named, and with none named it stops. It no
  longer looks at the working directory.
* `set_paper()` follows `usethis::proj_set()`: the user states the project
  once, and the calls after it work there.
* The examples, the tests and the vignette write only to `tempdir()`.

The points of the first review, fixed in the first resubmission:

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
  working directory: see above. `italicize_species()` requires `output`; it
  no longer writes beside its input by default.
* No function installs packages: `create_example_paper()` no longer offers
  to install vegan (in `Suggests`); it stops and says what to install.
* `installed.packages()` is no longer used; the base packages are listed.

Besides the points of the review, this version fixes defects and adds a few
features found since the first submission, so that you know everything that
changed:

* Fixed, since the first resubmission: on Windows a render could not find
  the citation style, because the paths handed to Pandoc had backslashes; a
  render that failed reported an error of cli's instead of Quarto's; a file
  open in Word was silently left in place of the new one; and outside
  RStudio the cover letter and `manuscript_stats()` did not find Pandoc.
  Everything now renders on Windows and macOS, checked with Quarto 1.7.32
  and the latest release.
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
* local Windows 11 (aarch64, in a virtual machine), R 4.6.1: R CMD check,
  and every function run with Quarto 1.10.18 on a project in a folder whose
  path has spaces and accents
* win-builder: Windows, R-devel (2026-10-14 r90673 ucrt)
* GitHub Actions: Ubuntu (R-devel, R-release, R-oldrel-1), macOS
  (R-release), Windows (R-release); and, rendering with Quarto 1.7.32 and
  with the latest release, Windows and macOS

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
