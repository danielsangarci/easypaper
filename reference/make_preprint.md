# Build a preprint deposit

[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)'s
sibling, for the other destination. Writes `submission/<label>/`: the
manuscript as ONE signed PDF – a preprint carries its authors, and is
not reviewed blind – its supplement as PDF too, every figure on its own,
and the data and code compendium, zipped. There is no cover letter:
there is no editor. Nor is there a short title, even when the manuscript
has one: a running head is what a journal asks for, not a preprint
server. A `README.md` inside says what goes to the preprint server and
what goes to the data repository, and what to do before pressing submit.

## Usage

``` r
make_preprint(
  journal = NULL,
  label = "bioRxiv",
  caption_style = "default",
  figure_format = "tiff",
  snapshot = TRUE,
  suppl_figures = "separate",
  line_numbers = TRUE,
  line_spacing = NULL,
  suppl_line_spacing = NULL,
  path = "."
)
```

## Arguments

- journal:

  The citation style. A preprint has no house style, so this is only
  about which convention you prefer to read. `NULL` takes the
  manuscript's own.

- label:

  Names the folder inside `submission/` and every file in it. Defaults
  to the server you are most likely to post to; change it for another
  one, or for a second version.

- caption_style:

  How figures and tables are named: `"default"`, `"abbrev"`, `"colon"`,
  `"compact"`, `"nature"`, or one of your own (see
  [`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md)).

- figure_format:

  The format of the standalone figures: `"tiff"` (what journals ask
  for), `"png"` or `"jpg"`.

- snapshot:

  `TRUE` (the default) records `renv.lock` before building the
  compendium.

- suppl_figures:

  `"separate"` (the default) leaves the supplementary figures and tables
  in the supplement, and rewrites their citations in the main text to
  "Figure S1". `"main"` keeps them at the end of the main text.
  Supplementary text (an extended Methods) always goes out on its own,
  with its own reference list.

- line_numbers:

  `TRUE` (the default) numbers every line of the manuscript PDF,
  continuously, which is what readers and reviewers of a preprint cite;
  `FALSE` leaves them unnumbered.

- line_spacing, suppl_line_spacing:

  The line spacing of the manuscript and of the supplement: `1`, `1.5`
  or `2`. `NULL`, the default, keeps the `linestretch` of the pdf format
  in `_quarto.yml` – `1.5` in the template.

- path:

  The project, or any folder inside it. The working directory by
  default, which is the project root once its `.Rproj` is open.

## Value

The path of the deposit, invisibly.

## Details

It needs a LaTeX installation for the PDF:
[`tinytex::install_tinytex()`](https://rdrr.io/pkg/tinytex/man/install_tinytex.html)
is enough.

## See also

[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md).

## Examples

``` r
if (FALSE) { # \dontrun{
# Inside a project, with its .Rproj open:
make_preprint()                     # -> submission/bioRxiv/
make_preprint(label = "EcoEvoRxiv")
} # }
```
