## Submission

This is a new submission.

## Test environments

* local macOS (aarch64), R 4.5.0
* win-builder, R-devel

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Notes for the reviewer

* The functions that build a manuscript -- `render_docx()`, `check_citations()`,
  `make_submission()` and the rest -- default to `path = "."`. Each acts on a
  project the user created with `create_paper()` and is working in: it looks
  for that project's `_quarto.yml` and `manuscript.qmd` at `path` or in a
  folder above it, stops with an error if there is none, and only ever writes
  inside that project. The examples and tests always pass a directory under
  `tempdir()`.
* The examples of the renders and of `make_submission()` and
  `make_preprint()` are in `\dontrun{}`: they need Quarto, a separate program,
  and take minutes. `edit_metadata()` opens an interactive editor, and
  `td_upload()` and its siblings need a Google account, so theirs are in
  `\dontrun{}` too. Every function that works without those has an example
  that runs, on a project created in `tempdir()`.
* The examples of `add_journal()` that need a connection are in `\dontrun{}`.
  The function has an example that runs offline, fetching a style from a
  local folder through its `repo` argument.
* `italicize_species()` queries the GBIF and Wikipedia APIs. Without a
  connection it does not fail: the names it could not check are left in roman
  and a warning says so. Its examples and tests do not use the network. The
  answers are cached in `tools::R_user_dir("easypaper", "cache")` unless the
  user gives another location; inside a project, in the project.
