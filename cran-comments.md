## Submission

This is a new submission.

## Test environments

* local macOS 27 (aarch64), R 4.5.0
* win-builder: Windows, R-devel (2026-10-05 r90641 ucrt)
* mac-builder: macOS 26.6 (aarch64), R 4.6.1 Patched
* GitHub Actions: Ubuntu (R-devel, R-release, R-oldrel-1), macOS
  (R-release), Windows (R-release)

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release. The only note, on win-builder, is "New
  submission"; mac-builder and GitHub Actions return no note.

## Notes for the reviewer

* The package drives Quarto, a separate program, through the quarto package:
  it is declared in `SystemRequirements`. Nothing that needs it runs on
  CRAN: the tests that render skip there, and the code chunks of the
  vignette are not evaluated.
* The functions that build a manuscript -- `render_docx()`, `check_citations()`,
  `make_submission()` and the rest -- default to `path = "."`. Each acts on a
  project the user created with `create_paper()` and is working in: it looks
  for that project's `_quarto.yml` and `manuscript.qmd` at `path` or in a
  folder above it, stops with an error if there is none, and only ever writes
  inside that project. The examples and tests always pass a directory under
  `tempdir()`.
* `\dontrun{}` is used only for code that cannot run in a check. Every
  function whose work does not need one of the things below has an example
  that runs, on a project created in `tempdir()`:
  * Quarto, and minutes of rendering: `render_html()`, `render_docx()`,
    `render_pdf()`, `render_supplementary()`, `render_all()`,
    `make_submission()` and `make_preprint()`.
  * An account: `td_upload()`, `td_update()` and `td_download()` need a
    Google account; `deposit_zenodo()` needs a Zenodo token and creates a
    deposit.
  * An interactive session: `edit_metadata("attributes")` and its siblings
    open an editor. `edit_metadata("write")`, which does not, runs in the
    example.
  * The working directory, or files only a real project has: the second
    part of the examples of `create_paper()` and `create_example_paper()`
    creates a project in the working directory, and that of `convert_data()`
    and `add_journal()` acts on the project the user is in (`add_journal()`
    also needs a connection). The first part of each runs, in `tempdir()`;
    `add_journal()` fetches its style from a local folder, offline.
* `italicize_species()` queries the GBIF and Wikipedia APIs. Without a
  connection it does not fail: the names it could not check are left in roman
  and a warning says so. Its examples and tests do not use the network. The
  answers are cached in `tools::R_user_dir("easypaper", "cache")` unless the
  user gives another location; inside a project, in the project.
* `create_example_paper()` needs vegan, in `Suggests`. When it is missing, it
  offers to install it, only in an interactive session and only on a yes;
  otherwise it stops and says what to install.
