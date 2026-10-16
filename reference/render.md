# Render the manuscript

Each render runs the checks first
([checks](https://danielsangarci.github.io/easypaper/reference/checks.md)),
keeps the licences and the deposit's metadata in step with the
manuscript, sets the scientific names of the references in italics,
renders with Quarto, repairs what Word would refuse to open, and copies
every figure to `figures/` as PNG, JPEG and TIFF at the `dpi` of
`_quarto.yml`, 600 in a new project. What it writes goes to the
project's `output/` folder.

## Usage

``` r
render_docx(
  journal = NULL,
  caption_style = "default",
  suppl_figures = "separate",
  path = NULL
)

render_pdf(
  journal = NULL,
  caption_style = "default",
  suppl_figures = "separate",
  path = NULL
)

render_html(journal = NULL, caption_style = "default", path = NULL)

render_supplementary(
  journal = NULL,
  caption_style = "default",
  output_format = "docx",
  files = NULL,
  blind = FALSE,
  path = NULL
)

render_all(journal = NULL, caption_style = "default", path = NULL)

preview(path = NULL)
```

## Arguments

- journal:

  The citation style, by the name of its `.csl` without the extension
  (see
  [`list_journals()`](https://danielsangarci.github.io/easypaper/reference/list_journals.md)).
  `NULL`, the default, takes the one the manuscript declares in its
  `csl:` line. Naming one here overrides that for this call only, and
  changes no file.

- caption_style:

  How figures and tables are named, in their captions and where the text
  cites them: `"default"` is what the `crossref:` block of `_quarto.yml`
  says (Figure 1. and Table 1. in a new project). The others are
  `"abbrev"` (Fig. 1.), `"colon"` (Figure 1:), `"compact"` (Fig. 1:) and
  `"nature"` (Figure 1 \|), or one you define, under a name of your
  choosing, in `caption-styles:` of the `easypaper:` block of
  `_quarto.yml`. The text cites with the caption's word unless the style
  gives it one of its own – `fig-prefix` beside `fig-title` in
  `crossref:`, or `fig-text` in a caption style – "Figure 1." under the
  figure, "Fig. 1" in the text. It does not follow `journal`: a citation
  style says nothing about figures or tables.

- suppl_figures:

  `"separate"` (the default) leaves the supplementary figures and tables
  in the supplement, and rewrites their citations in the main text:
  `@sfig-map` becomes "Figure S1", and `-@sfig-map`, the number alone,
  "S1". `"main"` keeps them at the end of the manuscript instead.

- path:

  The project, or any folder inside it. Left out, the project the
  working directory is in – its root once its `.Rproj` is open – and,
  since this writes into it, in an interactive session the first such
  call asks you to allow it, once a session; in a script, name it.

- output_format:

  `"docx"`, `"pdf"` or `"html"`.

- files:

  The supplementary sections to render. `NULL`, the default, renders
  every supplementary section: the numbered files of `_sections/` with
  `suppl` in their name, `12.1_suppl_material.qmd` in the template.

- blind:

  `TRUE` leaves the authors off the supplement, for one that travels
  with a double-blind submission.

## Value

The path of the file written, invisibly: several for
`render_supplementary()` when there are several supplements.
`render_all()` returns the `output/` folder, and `preview()` nothing
useful.

## Details

Every document is named after the project, the folder its `.Rproj` is
in: `manuscript_<project>`, `supporting_information_<project>`. Rendered
in the style of a journal other than the manuscript's own, the journal
is added – `manuscript_<project>_ecology-letters.docx` – so it leaves
yours as it was. Rename the folder and the next render follows.

- `render_docx()` writes `output/manuscript_<project>.docx`, on the
  project's Word template, and the supplement beside it, as
  `render_supplementary()` does.

- `render_pdf()` writes `output/manuscript_<project>.pdf`, its lines
  numbered as in the `.docx`, and the supplement beside it as `.pdf`:
  the title block flush left, with an ORCID icon beside each author who
  has one, the captions justified, and the Greek letters of the text
  printed, which LaTeX's font lacks. It needs a LaTeX installation:
  [`tinytex::install_tinytex()`](https://rdrr.io/pkg/tinytex/man/install_tinytex.html)
  is enough.

- `render_html()` writes `output/manuscript_<project>.html`: the working
  copy, in seconds instead of minutes. It does not record `renv.lock`,
  so rendering an old version to look into something never rewrites your
  record.

- `render_supplementary()` writes the supplement on its own:
  `output/supporting_information_<project>.docx`, or one file per
  supplementary section when there are several
  (`_sections/12.1_suppl_*.qmd`, `12.2_suppl_*.qmd` ...). Its own
  numbering (Figure S1...), its own Word template and its own reference
  list, left out when it cites nothing. It opens with "Supporting
  Information" and, under it, the reference of the paper it belongs to.

- `render_all()` runs `render_docx()`, `render_pdf()` and
  [`export_code()`](https://danielsangarci.github.io/easypaper/reference/export_code.md),
  in that order: every document to read, the supplements included, into
  `output/`. It does not build a submission: that is
  [`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md).

- `preview()` opens a live preview in the browser, rendered again every
  time you save a `.qmd`.

The manuscript and its supplement always come out as separate documents,
each with its own reference list. That is what a journal asks for, and
the only way the tables survive: merging them means handing both to
pandoc, which rebuilds the document and loses every column width.

The Word templates ship with the package. To use your own, put a file of
the same name – `word_plain_paper_style.docx` for the manuscript,
`word_plain_paper_style_supplementary_material.docx` for the supplement,
`word_cover_letter.docx` for the letter – in a `format/` folder in the
project; it is used instead.

## See also

[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
and
[`make_preprint()`](https://danielsangarci.github.io/easypaper/reference/make_preprint.md)
for what you send, and
[checks](https://danielsangarci.github.io/easypaper/reference/checks.md)
for what every render verifies first.

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, title = "Ant colonies", authors = "Ada Lovelace",
             git = FALSE)
#> Project created: /tmp/RtmpsfFR5O/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command

# The renders need Quarto, a program of its own (https://quarto.org).
if (FALSE) { # \dontrun{
render_html(path = dir)
render_docx(path = dir)
render_docx("ecology-letters", "abbrev", path = dir)
render_pdf(path = dir)
render_supplementary(path = dir)
render_all(path = dir)
list.files(file.path(dir, "output"))
} # }
unlink(dir, recursive = TRUE)
```
