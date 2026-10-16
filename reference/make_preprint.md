# Build a preprint deposit

[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)'s
sibling, for the other destination. Writes `submission/<label>/`: the
manuscript as ONE signed PDF – a preprint carries its authors, and is
not reviewed blind – its supplement as PDF too, every figure on its own,
and the data and code compendium, zipped. There is no cover letter:
there is no editor. Nor is there a short title, even when the manuscript
has one: a running head is what a journal asks for, not a preprint
server. The supplement names the server where a journal's would name the
journal – "Preprint, *bioRxiv*" – since the paper is in no journal yet.
A `README.md` inside says what goes to the preprint server and what goes
to the data repository, and what to do before pressing submit.

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
  figure_dpi = NULL,
  path = NULL
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
  one. Never overwritten: a second call builds the next version beside
  it, `bioRxiv_v2`, with its files named the same way.

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

- figure_dpi:

  The resolution the figures are drawn at, in dpi, for this call: `NULL`
  (the default) keeps the `dpi` of the knitr block of `_quarto.yml`, 600
  in a new project. The standalone figures are named with it and with
  the size they print at: `Figure_1_600dpi_180x120mm.tiff`.

- path:

  The project, or any folder inside it. Left out, the project the
  working directory is in – its root once its `.Rproj` is open – and,
  since this writes into it, in an interactive session the first such
  call asks you to allow it, once a session; in a script, name it.

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
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, title = "Ant colonies", authors = "Ada Lovelace",
             git = FALSE)
#> Project created: /tmp/RtmpudJD8L/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command

# It renders the manuscript, so it needs Quarto (https://quarto.org).
if (FALSE) { # \dontrun{
make_preprint(path = dir)
make_preprint(label = "EcoEvoRxiv", path = dir)
list.files(file.path(dir, "submission"))
} # }
unlink(dir, recursive = TRUE)
```
