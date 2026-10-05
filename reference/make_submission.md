# Build the folder you send to a journal

Writes `submission/<label>/`: the manuscript split the way journals with
double-blind review ask for – a title page, and a main text that opens
with the title and names nobody – or, signed, the main text alone; the
supplement as its own document, every figure on its own at 600 dpi, a
cover letter – dated, with the title of the manuscript, signed by the
corresponding author, and with the DOI of the data once
[`deposit_zenodo()`](https://danielsangarci.github.io/easypaper/reference/deposit_zenodo.md)
has reserved it; for a second journal, the text of the last letter with
those brought up to date – a checklist of what is left to do by hand,
and the data and code compendium, zipped, ready for Zenodo or Dryad.
Everything in it is rebuilt on every call except the cover letter, which
is never overwritten.

## Usage

``` r
make_submission(
  journal = NULL,
  label = NULL,
  caption_style = "default",
  figure_format = "tiff",
  blind = TRUE,
  snapshot = TRUE,
  suppl_figures = "separate",
  line_numbers = TRUE,
  line_spacing = 2,
  suppl_line_spacing = 1.5,
  path = "."
)
```

## Arguments

- journal:

  The citation style, by the name of its `.csl` without the extension
  (see
  [`list_journals()`](https://danielsangarci.github.io/easypaper/reference/list_journals.md)).
  `NULL`, the default, takes the one the manuscript declares in its
  `csl:` line.

- label:

  Names the folder inside `submission/` and every file in it. Left alone
  it is the journal's own name with the spaces taken out:
  `"ecology-letters"` gives `submission/EcologyLetters/`. A submission
  is never overwritten: when the folder is already there, the next
  version is built beside it – `JournalofEcology_v2`, `_v3` – with its
  files named the same way. Pass your own label for a trial you want to
  keep apart.

- caption_style:

  How figures and tables are named: `"default"`, `"abbrev"`, `"colon"`,
  `"compact"`, `"nature"`, or one of your own (see
  [`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md)).

- figure_format:

  The format of the standalone figures: `"tiff"` (what journals ask
  for), `"png"` or `"jpg"`.

- blind:

  `TRUE` (the default) splits the manuscript for double-blind review: a
  title page with the authors and the sections that identify them, a
  main text that names nobody, and a copy of the compendium that names
  nobody either. `FALSE` sends one signed main text, with all of it, and
  no title page.

- snapshot:

  `TRUE` (the default) records `renv.lock` before building the
  compendium. `FALSE` leaves a lockfile you maintain by hand alone.

- suppl_figures:

  `"separate"` (the default) leaves the supplementary figures and tables
  in the supplement, and rewrites their citations in the main text to
  "Figure S1". `"main"` keeps them at the end of the main text.
  Supplementary text (an extended Methods) always goes out on its own,
  with its own reference list.

- line_numbers:

  `TRUE` (the default) numbers every line of the main text and of the
  title page, continuously, which is what reviewers cite. `FALSE` leaves
  them unnumbered.

- line_spacing:

  The line spacing of the main text and of the title page: `2` (the
  default, double), `1.5` or `1`.

- suppl_line_spacing:

  The line spacing of the supplement: `1.5` (the default), `1` or `2`.
  Its lines are not numbered.

- path:

  The project, or any folder inside it. The working directory by
  default, which is the project root once its `.Rproj` is open.

## Value

The path of the submission folder, invisibly.

## Details

It records `renv.lock` first, so the compendium carries the environment
this submission came out of – the version of easypaper that built it
included.

Double-blind review also needs the sections that identify you off the
main text. They move to the title page: by default the Acknowledgements,
the CRediT statement, the conflict of interest statement and the data
availability statement, which is the list `blinded-sections:` sets in
the `easypaper:` block of `_quarto.yml`, in the order they come out on
the title page. The page is built from the manuscript and needs no file
of its own; a `title_page.qmd` in the project, to add a running head or
a word count, is used as the page.

The compendium is signed: `data_and_code.zip` is the one deposited, and
a deposit names its authors. A double-blind submission also gets
`data_and_code_blinded.zip`, for the reviewers: the same compendium with
the authors taken out of what the package writes into it – the creators
of the metadata (`creators.csv`, `dataspice.json` and its page), the
copyright line of `LICENSE-CODE.txt`, the README – and out of
`renv.lock`, which records the authors of every package it lists and the
pages of each, and easypaper itself, which the analysis does not use and
which, installed from GitHub, names the account it came from. A name,
email, ORCID, affiliation or account of an author still found in it – in
a script, in the data, a package of yours installed from GitHub – is
reported with the file it is in, to take out of the project by hand. An
account is the user part of an author's email and the owner of the
project's GitHub repository.

## See also

[`make_preprint()`](https://danielsangarci.github.io/easypaper/reference/make_preprint.md)
for a preprint server, and
[`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md)
for the documents alone.

## Examples

``` r
if (FALSE) { # \dontrun{
# Inside a project, with its .Rproj open:
make_submission()                               # -> submission/JournalofEcology/
make_submission()                               # again: JournalofEcology_v2/
make_submission("ecology-letters", figure_format = "png", blind = FALSE)
} # }
```
