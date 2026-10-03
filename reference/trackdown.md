# Edit a section with co-authors in Google Docs

Uploads one section of the manuscript to Google Drive, where co-authors
comment and edit it in Google Docs, and brings their changes back. One
section at a time: `manuscript.qmd` only holds the includes, so
uploading it would show them no text.

## Usage

``` r
td_upload(section, gpath = NULL, hide_code = TRUE, path = ".")

td_update(section, gpath = NULL, hide_code = TRUE, path = ".")

td_download(section, gpath = NULL, path = ".")
```

## Arguments

- section:

  The section, by the start of its file name in `_sections/`: `"02"` or
  `"02_introduction"`.

- gpath:

  The folder inside your Google Drive, e.g. `"papers/richness"`. `NULL`,
  the default, takes `trackdown-folder:` from the `easypaper:` block of
  `_quarto.yml`, or the root of the Drive.

- hide_code:

  `TRUE` (the default) hides the code chunks in the Google Doc, so
  co-authors see prose.

- path:

  The project, or any folder inside it. The working directory by
  default, which is the project root once its `.Rproj` is open.

## Value

Whatever trackdown returns, invisibly.

## Details

- `td_upload()` uploads a section for the first time.

- `td_update()` overwrites the Google Doc with your local version.

- `td_download()` brings the co-authors' edits back into the `.qmd`.

Always download before editing locally, and commit right after
downloading: git then shows exactly what each co-author changed. If they
would rather read the typeset paper, send them the `.docx` from
`output/` and keep this for the sections they are actively editing.

It needs the development version of trackdown, which reads `.qmd` files:
`remotes::install_github("ClaudioZandonella/trackdown")`. The version on
CRAN does not.

## Examples

``` r
if (FALSE) { # \dontrun{
td_upload("02_introduction")     # first upload
td_update("02_introduction")     # overwrite with your local version
td_download("02_introduction")   # bring back their edits
} # }
```
