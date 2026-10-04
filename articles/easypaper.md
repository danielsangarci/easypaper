# Getting started with easypaper

A scientific paper is not one document. It is text, analyses, figures,
tables, a bibliography, supplementary material, and — when the time
comes — a blinded manuscript, a title page, figures at the resolution
the journal demands, and a data deposit. easypaper writes a project that
holds only the paper, and its functions do the rest. This guide follows
a paper in the order you write it: set it up, bring the data in, write,
render, submit. The reference tables are kept for the [technical
details](#technical-details) at the end.

**Two families of functions, two jobs.** Most of what you call starts
with `render_` or `make_`, and the prefix tells you what you get.

|  | `render_*()` | `make_*()` |
|----|----|----|
| Makes | documents to **read** | what you **send** |
| Writes into | `output/`, overwritten every time | `submission/<label>/`, a folder you keep |
| When | every few minutes, while you write | a few times per paper |
| The functions | [`render_html()`](https://danielsangarci.github.io/easypaper/reference/render.md), [`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md), [`render_pdf()`](https://danielsangarci.github.io/easypaper/reference/render.md), [`render_supplementary()`](https://danielsangarci.github.io/easypaper/reference/render.md), and [`render_all()`](https://danielsangarci.github.io/easypaper/reference/render.md) for all of them | [`make_preprint()`](https://danielsangarci.github.io/easypaper/reference/make_preprint.md), [`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md) |

Render as often as you like: nothing in `output/` is precious. A
`make_*()` is a moment you will return to — blinded, split, figures
apart, data and code packed — so it is never part of a “do everything”
call.

All of them at once, in the order a paper meets them:

``` r

# while you write
render_html()            # the manuscript, in seconds
preview()                # live: reloads every time you save

# documents to read, in output/
render_docx()            # the .docx, in the journal's style
render_pdf()             # the .pdf
render_supplementary()   # the supplement, with its own references
render_all()             # the three above, and the analysis code

# what you send, in submission/
make_preprint()          # the preprint and its data deposit
make_submission()        # the journal's folder, double-blind
```

## The workflow at a glance

| Step | Functions | What they do |
|----|----|----|
| [1. Set up](#setup) | [`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md), [`create_example_paper()`](https://danielsangarci.github.io/easypaper/reference/create_example_paper.md), [`add_journal()`](https://danielsangarci.github.io/easypaper/reference/add_journal.md) | Write an empty project, or one with a small worked study in it; fetch a journal’s style |
| [2. Bring the data](#data) | [`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md) | Copy or convert your originals into `data/`, in open formats |
| [3. Write and check](#write) | [`render_html()`](https://danielsangarci.github.io/easypaper/reference/render.md), [`preview()`](https://danielsangarci.github.io/easypaper/reference/render.md), [`check_species_text()`](https://danielsangarci.github.io/easypaper/reference/check_species_text.md), [`manuscript_stats()`](https://danielsangarci.github.io/easypaper/reference/manuscript_stats.md) … | See the manuscript as you write it; find what is missing or wrong before a journal does |
| [4. Render](#render) | [`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md), [`render_pdf()`](https://danielsangarci.github.io/easypaper/reference/render.md), [`render_supplementary()`](https://danielsangarci.github.io/easypaper/reference/render.md), [`render_all()`](https://danielsangarci.github.io/easypaper/reference/render.md) | The documents to read, in a journal’s style, into `output/` |
| [5. Submit](#submit) | [`make_preprint()`](https://danielsangarci.github.io/easypaper/reference/make_preprint.md), [`deposit_zenodo()`](https://danielsangarci.github.io/easypaper/reference/deposit_zenodo.md), [`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md) | The preprint and its data deposit, the DOI of the data, and the folder a journal asks for, into `submission/` |

Every function works on the project the working directory is in, from
any folder inside it, or on the one its `path` argument names. Each has
a help page with its arguments explained:
[`?create_paper`](https://danielsangarci.github.io/easypaper/reference/create_paper.md),
[`?render`](https://danielsangarci.github.io/easypaper/reference/render.md),
[`?make_submission`](https://danielsangarci.github.io/easypaper/reference/make_submission.md),
[`?checks`](https://danielsangarci.github.io/easypaper/reference/checks.md).
[`?easypaper`](https://danielsangarci.github.io/easypaper/reference/easypaper-package.md)
lists them all.

## 1. Set up

### Creating a project

``` r

library(easypaper)

create_paper("my_paper",
             title   = "Manuscript title here",
             authors = c("First Author", "Second Author"))
```

In RStudio the same thing is **File \> New Project \> New Directory \>
Reproducible Quarto manuscript**, with fields for the title and the
authors.

The title and the authors are optional; without them the YAML keeps its
placeholders, and every render warns you about them until you replace
them. Each author points at an affiliation of its own in the YAML, to be
filled in (see [Authors and affiliations](#authors-and-affiliations)).
The other arguments are in the [technical
details](#the-arguments-of-create_paper).

Then open the `.Rproj` it leaves behind, and
[`library(easypaper)`](https://github.com/danielsangarci/easypaper).
Every function works on the project the working directory is in.

### An example to read first

[`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md)
writes the structure and nothing else. To see how each part of a
manuscript is written in it before you write your own,
[`create_example_paper()`](https://danielsangarci.github.io/easypaper/reference/create_example_paper.md)
writes the same project with a small study in it:

``` r

create_example_paper("example_paper")   # needs the vegan package
```

The study re-analyses the trees of the 50-ha plot of Barro Colorado
Island, Panama, as the vegan package distributes them \[`BCI`, collected
by Condit et al. 2002, *Science* 295: 666–669\]: species richness by
habitat with a Poisson GLM, and the composition of the tree assemblages
with a PERMANOVA, a test of the homogeneity of their dispersions
(PERMDISP) and an NMDS. It needs vegan, for the data and the analysis,
and offers to install it when it is missing. Each section shows one
thing done the way the package expects it:

| Where | What it shows |
|----|----|
| `manuscript.qmd` | a title, a short title, two authors sharing an affiliation, one with two, the corresponding author, and the journal it is written for, *Journal of Ecology*, whose style is in `references/` |
| `01_abstract.qmd` | the abstract, and the keywords on one line under it |
| `02_introduction.qmd` | citations in brackets, `[PERMANOVA, @Anderson2001]`, and in the sentence, `@Condit2002` |
| `03_methods.qmd` | the text of the Methods, and above it what every analysis needs: the packages, loaded in a chunk without cache, and the data, read from `data/` |
| `04.1_richness.qmd`, `04.2_composition.qmd` | each analysis beside the text that reports it, in a file named after it, as an author renames the template’s `04.1_results1.qmd` — the GLM of richness, then the PERMANOVA, PERMDISP and NMDS of composition, cached; every number written by inline R, never typed — even the words that depend on a result (“differed”, “did not differ”); a species name written by R and put in italics |
| `05_discussion.qmd` | interpretation without the numbers, and the limits of the design |
| `06`–`09` | the statements at the end, filled in, with the DOI placeholder [`deposit_zenodo()`](https://danielsangarci.github.io/easypaper/reference/deposit_zenodo.md) fills |
| `10_figures.qmd`, `11_tables.qmd` | two figures, an NMDS with species names in italics among them, and two flextables with the three rules |
| `12.1_suppl_material.qmd` | a supplementary figure and a supplementary table, which read their own data |
| `data/` | the two tables of `BCI` as `.csv`, species named as a paper names them |

[`render_html()`](https://danielsangarci.github.io/easypaper/reference/render.md)
in it gives the study, with every number computed from the data. Its
authors and affiliations are made up; the data are Condit et al.’s. It
takes the same `path`, `overwrite`, `git` and `open` as
[`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md);
the title and the authors are the example’s own.

### What lands on disk

`create_paper("my_paper")` writes this:

    my_paper/
    ├── manuscript.qmd        the spine: title, authors, journal, includes
    ├── supplementary.qmd     the supplement, as a document of its own
    ├── _quarto.yml           the formats, and the settings of easypaper
    ├── _sections/            the text, one file per section: you write here
    │   ├── 01_abstract.qmd
    │   ├── 02_introduction.qmd
    │   ├── ...
    │   └── 12.1_suppl_material.qmd
    ├── R/setup.R             seed, palette, table and figure helpers
    ├── data/                 the data, in open formats: what gets published
    │   └── metadata/         their description, for the data deposit
    ├── references/           the .bib you cite from, one .csl per journal
    ├── figures/ output/ cache/   written by every render: disposable
    └── README.md, LICENSE, LICENSE-CODE, my_paper.Rproj, .gitignore

One more folder, `submission/`, appears when you build what you send, in
[step 5](#submit). You write in `_sections/`. Everything else is set
once, or written for you.

`manuscript.qmd` holds no prose. It is a spine: the YAML with title and
authors, and a list of includes in reading order.

    {{< include _sections/02_introduction.qmd >}}
    {{< include _sections/03_methods.qmd >}}
    {{< include _sections/04.1_results1.qmd >}}

The number in front of each file is **its place in the paper**, so the
folder reads in the order the paper does: `01_abstract.qmd` to
`05_discussion.qmd`, the statements at the end
(`06_acknowledgements.qmd`, `07_credit_statement.qmd`,
`08_conflict_of_interest.qmd`, `09_data_availability.qmd`), then
`10_figures.qmd`, `11_tables.qmd` and `12.1_suppl_material.qmd`. Two
digits, so `10` does not sort before `2`. A section split in two is
numbered as you would in the text: Results is `04.1` and `04.2`, and the
supplement starts at `12.1`, so a second one, `12.2_suppl_methods.qmd`,
goes beside it without renaming anything. Still, nothing depends on the
alphabetical order of the files — the build order is the order of those
includes, and every render reads it from there.

Everything else follows one rule: **paths are relative to the project
root**, in the YAML and in the R code alike. `_quarto.yml` sets
`execute-dir: project`, so a chunk runs with the working directory at
the root, and
[`here::here()`](https://here.r-lib.org/reference/here.html) resolves
the same way.

There is no build code in the project: no `make.R`, no scripts of
functions. The functions that render and assemble it live in easypaper,
and so do the three Word templates — the manuscript (line-numbered,
ragged right), the supplement and the cover letter (both justified,
neither numbered). A project that wants its own puts a file of the same
name in a `format/` folder, and that one is used instead.

Everything under `output/`, `figures/` and `cache/` is disposable by
design, and left out of git by `.gitignore`: every render writes it
again. If deleting it makes you nervous, something is being done by hand
that should be done by code.

### Choosing the journal

The `csl:` line of `manuscript.qmd` says where the paper is going,
beside its title and its authors, and every `render_*()` and `make_*()`
function reads it from there: none of them has to be told. The template
ships one style, `journal-of-ecology.csl`, as an example. Any other
journal’s is one call away, and it goes where the renders look:

``` r

list_journals()                  # the styles you have
add_journal("ecology-letters")   # -> references/ecology-letters.csl
render_docx("ecology-letters")   # this render only, in that style
```

Naming a journal in the call wins for that call alone and changes no
file, which is what you want to see the paper in another journal’s
style. To move the paper for good, edit the `csl:` line.

The name is the one the official CSL repository uses — the file name
without `.csl`, lower case, hyphens — and Zotero’s style finder at
<https://www.zotero.org/styles> searches it by journal; its URLs work
too. Most journals have a *dependent* style, a few lines pointing at the
parent whose rules they share. Pandoc cannot follow that pointer, so
what lands in the project are the parent’s rules under the name you
asked for, and the message says which parent it was.

### A history from the first line

The project is also a **git repository**, with the first commit already
made (`git = FALSE` if you would rather not). That is local and private,
and unrelated to GitHub. The point comes months later:
`git tag submission-1` when you submit lets you return to the exact
state that produced what you sent, and
`git diff submission-1 submission-2 -- _sections/` writes half of your
response to reviewers. `output/`, `figures/` and `cache/` stay out of
it: they are regenerable, and git is poor with binaries. `submission/`
stays in, because it holds the cover letter you write.

## 2. Bring the data

`data/` is **the folder that publishes**. Whatever is in it is what the
analysis reads, what the metadata describes and what the data deposit
carries. A file that is not there does not reach the deposit.

Your originals live wherever you keep them — a folder in the project, a
shared drive, your downloads — and they stay there.
[`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
brings a **copy** into `data/`, in a format that will still open in
twenty years:

``` r

convert_data("originals/counts.xlsx")   # one workbook, one .csv per sheet
convert_data("originals")               # a whole folder at once
```

A spreadsheet becomes `.csv`; a file already in an open format (`.csv`,
`.gpkg`, `.tif`, `.fasta` …) is copied as it is; what nothing can open
is left where it is and named on screen. The original is only ever read,
and
[`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
never runs by itself. Which format takes which road, and how to add your
own, is in the [technical
details](#what-convert_data-does-with-each-file).

Three rules follow, and they are the ones worth holding onto:

- **Read from `data/`, never from wherever the original lives.** An
  analysis that reads the original works perfectly on your machine and
  publishes a compendium with no data in it — and nothing would have
  told you.
- **Keep the originals.** Every conversion costs something: an `.xlsx`
  loses its formulas, an `.sav` its value labels. Two years from now,
  when a number in `data/` looks wrong, the original is the only thing
  that answers.
- **`data/` is not “my clean data”.** It holds a format conversion, not
  a transformation. Filtering, recoding and excluding belong in the
  chunk that needs them, where a reviewer can read the decision.

[`check_data()`](https://danielsangarci.github.io/easypaper/reference/checks.md)
reports what is sitting in `data/` that the analysis never reads — it
travels to the repository all the same.
[`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
works in any folder, whether or not easypaper created it.

## 3. Write and check

### The writing loop

1.  Fill in the affiliations in the YAML of `manuscript.qmd`. The names
    are already there if you passed `authors`, each pointing at an
    affiliation of its own.
2.  Write. `_sections/02_introduction.qmd` is plain markdown: headings
    and paragraphs, nothing to declare.
3.  [`render_html()`](https://danielsangarci.github.io/easypaper/reference/render.md)
    whenever you want to look at it — seconds, not minutes — or
    [`preview()`](https://danielsangarci.github.io/easypaper/reference/render.md),
    which reloads every time you save.

From there it is one loop — write, render, repeat. `03_methods.qmd` is
the text of the Methods, with a chunk above it for what every analysis
needs: the packages and the data, read from `data/` with the path
relative to the project root. Each analysis then lives in the results
section that reports it, right before its text, and starts from that
chunk and from nothing of another results section. Name each results
file after its analysis: rename `04.1_results1.qmd` to
`04.1_richness.qmd`, say, and change its include line in
`manuscript.qmd` to match. In `03_methods.qmd`:

    ```{r}
    #| label: data
    richness <- readr::read_csv(here::here("data/richness.csv")) |>
      dplyr::filter(!is.na(S), status != "dead")
    ```

    ## Statistical analysis

    Richness was modelled with a negative binomial GLMM...

and in `04.1_richness.qmd`, the analysis and what it found:

    ```{r}
    #| label: richness-model
    #| cache: true
    m1 <- glmmTMB::glmmTMB(S ~ treatment + (1 | plot),
                           family = nbinom2, data = richness)
    ```

    Richness was higher in the treatment
    (beta = r round(fixef(m1)$cond[2], 2)), as shown in @fig-richness.

[`export_code()`](https://danielsangarci.github.io/easypaper/reference/export_code.md)
writes all of it into one script, `analysis_code.R`, in that order,
opening with a table of contents that says on which line each section
starts and which chunks it holds: the richness model is found under
`04.1_richness.qmd`.

Cleaning happens in the chunk of the Methods, from the input `.csv`,
never as a derived file saved in `data/`. Excluding individuals or
recoding a factor is a scientific decision: it belongs in code a reader
can check, not in a spreadsheet nobody can trace. `#| cache: true`
covers the cost of recomputing it — and
[`clean_cache()`](https://danielsangarci.github.io/easypaper/reference/clean_cache.md)
empties that cache, which is what you run when the data underneath a
chunk changed, because a change in `data/` is the one thing knitr’s
cache does not notice.

### Authors and affiliations

You write the authors and their affiliations in the YAML of
`manuscript.qmd`, the way Quarto documents them, and never a number:

``` yaml
author:
  - name: Ana Garcia
    affiliations: [ecology]
    email: ana.garcia@example.org
    corresponding: true
  - name: Luis Perez
    affiliations: [ecology, institute]
affiliations:
  - id: ecology
    name: University X, Department of Ecology, City, Country
  - id: institute
    name: Institute Y, City, Country
```

Every render prints it as a paper does — the authors on one line, one
after another, and the affiliations under them:

> Ana Garcia^(1,\*), Luis Perez^(1,2)
>
> ¹ University X, Department of Ecology, City, Country
>
> ² Institute Y, City, Country
>
> ^(\*) Correspondence: <ana.garcia@example.org>

The affiliations are numbered in the order the authors name them, so
reordering the authors renumbers them, and two authors who share one
share its number. An affiliation can also be written in place, quoted —
`affiliations: ["University X, City, Country"]` — or with Quarto’s own
fields (`department:`, `city:`, `country:` …). An id that is not in the
list stops the render: it is a typo, and would otherwise reach the
journal. An affiliation no author names, or one still from the template,
gets a warning.

Quarto cannot do this on its own: in a `.docx` it prints the names
alone, with no affiliation and no asterisk, and it gives each author a
paragraph of their own. So every render of the package hands Quarto the
names as one line, marks included, and the chunk right under the YAML,
[`easypaper::affiliations()`](https://danielsangarci.github.io/easypaper/reference/affiliations.md),
writes the affiliations. In the `.docx` they have a paragraph style of
their own, *Affiliation*, without the first-line indent of the text,
which you can restyle in Word for all of them at once; the keywords line
under the abstract has no indent either. A double-blind main text leaves
that chunk out, and the title page is given it. Quarto’s own preview —
[`preview()`](https://danielsangarci.github.io/easypaper/reference/render.md),
or `quarto preview` — draws the title block its own way, and the chunk
prints nothing there.

### Short title

Some journals ask for a short title, or running head. Write it in the
YAML of `manuscript.qmd`, under the title — the template has the line,
commented out:

``` yaml
title: "Chemical mimicry in the parasitic butterfly Maculinea rebeli"
short-title: "Chemical mimicry in Maculinea"
```

Every document prints it under the title as “Short title: Chemical
mimicry in Maculinea”, as a second line of the title itself, in the same
font and size: the main text, signed or blinded, the title page, the
`.pdf` and the `.html`. The preprint of
[`make_preprint()`](https://danielsangarci.github.io/easypaper/reference/make_preprint.md)
is the exception: a running head is what a journal asks for, not a
preprint server. Leave the line out and nothing is printed. The summary
at the end of every render counts its characters, which is how journals
limit it.

### Figures and tables

Both are chunks, and both follow the same three rules: a label beginning
with `fig-` or `tbl-`, the legend as a chunk option, and
`#| include: true`. That last one is not decoration — the project sets
`include: false` for every chunk in `_quarto.yml`, so an analysis prints
nothing and only a float asks to be shown.

    ```{r}
    #| label: fig-richness
    #| include: true
    #| fig-width: 7.09
    #| fig-height: 6.30
    #| fig-cap: "Richness by treatment. Supports *italics*, **bold** and $equations$."
    boxplot(S ~ treatment, data = richness)
    ```

Cite it from the text as `@fig-richness` and Quarto writes *Figure 1*.
The number comes from the **order of appearance** in
`_sections/10_figures.qmd`: move the chunk and every reference in the
manuscript follows. `fig-width` and `fig-height` are in inches, which is
not how journals state them — `mm(180)` converts, and 180 mm is the
usual two-column width, 80–90 mm one column.

A table is the same with `tbl-cap` in place of `fig-cap`:

    ```{r}
    #| label: tbl-models
    #| include: true
    #| tbl-cap: "Model coefficients."
    rule <- fp_border_default(style = "solid", color = "black", width = 1)

    flextable(tab) |>
      hline_top(border = fp_border_default(width = 0), part = "all") |>
      hline_bottom(border = rule, part = "all") |>
      colformat_double(j = "p", digits = 3, suffix = stars_pval(tab$p)) |>
      fit_flextable_to_page()
    ```

Two things there are worth the line they take. **Write every table as a
flextable**:
[`knitr::kable()`](https://rdrr.io/pkg/knitr/man/kable.html) hands
pandoc a plain markdown table and pandoc gives every column the same
width, so a long heading breaks across two lines while a short one sits
in acres of space. And **let Quarto write the caption** —
[`flextable::set_caption()`](https://davidgohel.github.io/flextable/reference/set_caption.html)
on top of `tbl-cap` prints it twice.

Three helpers come from `R/setup.R`, which is yours to edit and which
the render loads before the first line of text:

|  |  |
|----|----|
| `mm(180)` | millimetres to the inches `fig-width` wants |
| `fit_flextable_to_page(ft, pgwidth = 5.5)` | `autofit()` plus a ceiling. The table keeps the width its content needs and is only scaled down if it would run off the page; it is never stretched to fill the line, because Quarto puts a captioned table in a container 5.5 inches wide and a wider one reaches Word out of line |
| `stars_pval(p)` | significance stars, as the `suffix` of `colformat_double()` so the p-value stays a number and is formatted rather than pasted together as text |

Every render writes the figures to `figures/png/` at 600 dpi, and copies
them to `figures/jpg/` and `figures/tiff/` — which is what a journal
asks for on acceptance, and what
[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
renumbers into `Figure_1.tiff` in the order the reader meets them.
[`export_figure_formats()`](https://danielsangarci.github.io/easypaper/reference/export_figure_formats.md)
makes those copies on its own, from the PNGs already there.

How a caption starts — *Figure 1.*, *Fig. 1:*, *Figure 1 \|* — is set
once for the paper, or for one render; see [How figures and tables are
named](#how-figures-and-tables-are-named).

### Supplementary material

Two kinds, told apart by what the file contains — nothing to declare:

- **Figures and tables**: any supplementary section — a numbered file of
  `_sections/` with `suppl` in its name — defining an `sfig` or
  `stbl` div. They are numbered `Figure S1`, `Table S1`, on a counter of
  their own, so a supplementary figure never advances the numbering of
  `Figure 1`. They are the same chunks as above, with `sfig-` and
  `stbl-` labels.
- **Text** (an extended Methods, say): a supplementary file with no
  floats. It always leaves as its own document, which is the point — its
  reference list is independent from the main text’s.

The supplement is also rendered as **a document of its own** — by
[`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md),
[`render_pdf()`](https://danielsangarci.github.io/easypaper/reference/render.md),
[`render_supplementary()`](https://danielsangarci.github.io/easypaper/reference/render.md)
and
[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
— and that document runs `R/setup.R` and the supplementary file only,
not the chunks of the other sections. An object made in the Methods is
not there: what a supplementary figure or table needs, read or compute
it in a chunk at the top of its own file.
[`render_html()`](https://danielsangarci.github.io/easypaper/reference/render.md),
one document with everything in it, would not tell you, so render the
`.docx` once before you rely on it.

Where the figures end up is decided when you submit, and the citations
work either way:

``` r

make_submission()                        # own document
make_submission(suppl_figures = "main")  # end of the main text
```

### Writing with co-authors

Co-authors who do not use R can comment and edit in Google Docs, one
section at a time, through the trackdown package:

``` r

td_upload("02_introduction")     # the section, as a Google Doc
td_download("02_introduction")   # their edits, back into the .qmd
td_update("02_introduction")     # your local version, over the Google Doc
```

The chunks are hidden in the Google Doc, so they see prose. Download
before you edit locally, and commit right after downloading: git then
shows exactly what each co-author changed. The Drive folder is
`trackdown-folder:` in `_quarto.yml`. trackdown has to be its
development version, the only one that reads `.qmd`:
`remotes::install_github("ClaudioZandonella/trackdown")`. Those who
would rather read the typeset paper get the `.docx` from `output/`.

### Scientific names

**In the reference list**, there is nothing to do. citeproc leaves
“Pinus halepensis” in roman, so every render finds the genera and
species in the titles of your references, checks them against GBIF, and
hands Quarto a copy of the `.bib` with them in italics. What a title
cannot settle (“Gorilla Conservation”) is reported, with the line to
mark. How it decides, and how to turn it off, is in the [technical
details](#scientific-names-in-the-references).

**In the text**, the package does not rewrite what you write, but it can
read it the way an editor does.
[`check_species_text()`](https://danielsangarci.github.io/easypaper/reference/check_species_text.md)
goes through every section, the captions and the supplement, and reports
each scientific name not written the way journals ask, with the file,
the line and what to write:

``` r

check_species_text()
```

    Scientific names in the text: Fagus sylvatica, Formica rufa, Lasius niger
    5 things to look at:
      _sections/01_abstract.qmd:3      F. rufa       first mention abbreviated -> Formica rufa
      _sections/02_introduction.qmd:4  Formica rufa  first mention without its authority -> Formica rufa Linnaeus, 1761
      _sections/02_introduction.qmd:9  Formica rufa  not in italics -> *Formica rufa*
      _sections/03_methods.qmd:12      F. rufa       abbreviated at the start of a sentence -> Formica rufa
      _sections/03_methods.qmd:20      Formica spp.  spp. in italics -> *Formica* spp.

What it asks for:

- **Italics** for the genus and the epithet, abbreviated or not, and for
  a genus on its own; `sp.` and `spp.` in roman.
- **The name in full the first time**, and the genus abbreviated after
  that — but not at the start of a sentence, and not when two genera of
  the text share the initial (*Formica* and *Fagus*), where *F.* would
  not say which. Headings and captions, which are read on their own, may
  give it in full.
- **The authority at the first mention** in the main text. The one GBIF
  gives is suggested.

The abstract, the main text and the supplement are read as three
documents — a name goes in full at its first mention in each — and the
title is checked for italics alone. `authority = FALSE` and
`abbreviate = FALSE` turn those two rules off for a journal that does
not follow them, and `exclude` takes a pair of words that looks like a
name and is not one.

It is optional, and never runs on its own: no render and no `make_*()`
calls it. The names are looked up in GBIF through the same cache as the
references, `references/species_cache.rds`, so a name already looked up
needs no connection. Without one, a pair you already wrote in italics is
taken for a name, and a warning says what could not be checked.

### The checks

Every render runs them, and you can call them yourself:

``` r

check_packages()    # packages the manuscript loads that are not installed
check_citations()   # @keys with no entry in references/, and the reverse
check_crossrefs()   # @fig-/@tbl- with no target, and figures nobody cites
check_title()       # does the manuscript still have the template's title?
check_renv()        # is renv.lock there, and does it match what you use?
check_data()        # files in data/ that the analysis never reads
check_species()     # scientific names of the references left in doubt
```

[`check_crossrefs()`](https://danielsangarci.github.io/easypaper/reference/checks.md)
has caught more submissions than the rest together: a figure defined and
never cited is a figure the journal will ask you about. It reads the
citations R code writes as well — a `sprintf("as in @fig-x")` printed
with inline R, a function in `R/setup.R` that returns one — so a figure
cited only from there is not reported as uncited.

Every render and every `make_*()` also ends with a summary of the
manuscript: what a journal’s submission form asks for.
[`manuscript_stats()`](https://danielsangarci.github.io/easypaper/reference/manuscript_stats.md)
says it on its own:

``` r

manuscript_stats()
#> Manuscript summary
#>   Title                          87 characters
#>   Title, without spaces          75 characters
#>   Short title                    38 characters
#>   Short title, without spaces    34 characters
#>   Abstract                      243 words
#>   Keywords                        5
#>   Main text                    6120 words
#>   Main text + references       7480 words
#>   References                     61
#>   Figures                         5
#>   Tables                          2
#>   Supplementary figures           3
#>   Supplementary tables            1
```

Words are counted the way Word counts the rendered text: a citation as
the “(Akino et al. 1999)” the journal’s style prints, a cross-reference
as “Figure 1”, code and comments not at all. The main text is
Introduction to Discussion: acknowledgements, funding, author
contributions, conflicts of interest, data availability and ethics are
left out, whatever they are called. “Main text + references” adds the
reference list, as the journal’s style prints it.

## 4. Render

Rendering produces documents to read: one file each, complete, with the
authors on the front, written into `output/`. You will do it a hundred
times.

``` r

render_html()                       # seconds, while you write
render_docx()                       # the .docx, in the journal manuscript.qmd names
render_pdf()                        # the .pdf, for a preprint server or for reading
render_all()                        # docx and pdf, with their supplements, and the code
```

| Command | What comes out, in `output/` |
|----|----|
| [`render_html()`](https://danielsangarci.github.io/easypaper/reference/render.md) | the working `.html`, images embedded |
| [`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md) | `manuscript_<journal>.docx`, with the journal’s citation style and Word template, and the supplement beside it, `supporting_information.docx` |
| [`render_pdf()`](https://danielsangarci.github.io/easypaper/reference/render.md) | `manuscript_<journal>.pdf`, its lines numbered as in the `.docx`, for a preprint server or for reading, and the supplement beside it as `.pdf` |
| [`render_supplementary()`](https://danielsangarci.github.io/easypaper/reference/render.md) | the supplement alone, `supporting_information.docx`, with its own reference list: when only the supplement changed |
| [`export_code()`](https://danielsangarci.github.io/easypaper/reference/export_code.md) | `analysis_code.R`, the code of every chunk in order, opening with a table of contents — the line each section starts on and the chunks it holds — and `sessionInfo.txt` |
| [`preview()`](https://danielsangarci.github.io/easypaper/reference/render.md) | nothing on disk: a live `.html` in the viewer that reloads every time you save |
| [`render_all()`](https://danielsangarci.github.io/easypaper/reference/render.md) | [`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md), [`render_pdf()`](https://danielsangarci.github.io/easypaper/reference/render.md) and [`export_code()`](https://danielsangarci.github.io/easypaper/reference/export_code.md), in order: both documents with their supplements, and the code |

The prefixes are a convention, and worth reading once: **`render_`**
writes documents to read into `output/`. **`make_`** assembles what you
send into `submission/`. **`export_`** derives a file without going
through Quarto. And **`check_`** looks and warns, but never writes.

[`render_all()`](https://danielsangarci.github.io/easypaper/reference/render.md)
leaves out
[`render_html()`](https://danielsangarci.github.io/easypaper/reference/render.md),
because the `.html` is the one you run while writing and it would only
slow down the batch. And it builds no submission: that is
[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md),
in [the next step](#submit).

[`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md),
[`render_pdf()`](https://danielsangarci.github.io/easypaper/reference/render.md)
and
[`render_supplementary()`](https://danielsangarci.github.io/easypaper/reference/render.md)
record `renv.lock` when they finish: a document somebody else will read
carries the environment it came out of, and it costs about three tenths
of a second. The `.html` is left out on purpose — it is the loop you run
every two minutes, and it is also what you render after restoring an old
environment to look into a reviewer’s complaint, where overwriting your
record is the last thing you want. The lockfile is only rewritten when
the environment really moved, so most renders leave it alone and say
nothing.

**None of those calls names a journal, and none of them has to**: they
read the `csl:` line of `manuscript.qmd` (see [Choosing the
journal](#choosing-the-journal)). Of the three arguments below,
[`render_html()`](https://danielsangarci.github.io/easypaper/reference/render.md)
and
[`render_all()`](https://danielsangarci.github.io/easypaper/reference/render.md)
take the first two;
[`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md)
and
[`render_pdf()`](https://danielsangarci.github.io/easypaper/reference/render.md)
take all three.

| Argument | Default | What it decides |
|----|----|----|
| `journal` | the manuscript’s own | Which `.csl` in `references/` sets the citation style. Left out, it is the one `manuscript.qmd` declares in its `csl:` line; naming one here wins for that call. [`list_journals()`](https://danielsangarci.github.io/easypaper/reference/list_journals.md) lists the ones you have |
| `caption_style` | `"default"` | How figures and tables are named, in their captions and in the text: `"default"` is what the `crossref:` block of `_quarto.yml` says (*Figure 1.* and *Table 1.* in a new project), `"abbrev"` gives *Fig. 1.*, `"colon"` *Figure 1:*, `"compact"` *Fig. 1:*, `"nature"` *Figure 1* followed by a vertical rule. Your own go under `caption-styles:` in `_quarto.yml`: see [How figures and tables are named](#how-figures-and-tables-are-named) |
| `suppl_figures` | `"separate"` | Whether the supplementary figures and tables travel with the supplement or stay at the end of the manuscript. Either way they are cited from the main text |

The main text comes out with its lines numbered, in the `.docx` and in
the `.pdf` alike, and the supplement without them. Whether to number
them, and the line spacing, belong to what you send: they are arguments
of [`make_preprint()`](#the-preprint-deposit) and
[`make_submission()`](#submitting-to-a-journal).

One thing worth reading once: **the manuscript and its supplement are
never joined into a single file**. Each render writes one document per
section, into `output/`, each with its own reference list. Joining them
would mean handing both to pandoc, which rebuilds a `.docx` rather than
copying it, and a rebuilt table loses the column widths it was given:
the headings reach Word broken across two lines. One document per
section is also the shape a journal asks for.

[`render_supplementary()`](https://danielsangarci.github.io/easypaper/reference/render.md)
has three arguments of its own: `output_format` (`"docx"` by default,
`"pdf"` for a preprint deposit), `files`, a subset of the supplementary
documents — which is how
[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
renders only the supplementary *text* when the figures are staying in
the main document — and `blind` (`FALSE` by default), which drops the
authors from the supplement the way a double-blind submission needs.

## 5. Submit

A submission is a moment you will want to return to, so it is never part
of
[`render_all()`](https://danielsangarci.github.io/easypaper/reference/render.md).
A `make_*()` rewrites `renv.lock` to record the environment this exact
version came out of, and stamps a label on every file it writes, into a
folder of its own under `submission/`. Folding that into a “build
everything” command would mean rewriting your dependency manifest every
time you fixed a typo.

A paper usually goes out twice: as a preprint, with its data deposit,
and to a journal.

### The preprint deposit

A preprint goes to two places at once — the manuscript to a server, the
data and code to a repository — and
[`make_preprint()`](https://danielsangarci.github.io/easypaper/reference/make_preprint.md)
builds both halves into `submission/bioRxiv/`.

``` r

make_preprint()                       # -> submission/bioRxiv/
make_preprint(label = "EcoEvoRxiv")   # another server
make_preprint(label = "bioRxiv_v2")   # the revised version
make_preprint(line_numbers = FALSE, line_spacing = 2)  # unnumbered, double-spaced
```

    submission/bioRxiv/
      README.md                     what goes to the server, what to the repository
      manuscript/
        preprint_bioRxiv.pdf        the manuscript, signed
        supporting_information_bioRxiv.pdf
        figures/Figure_1.tiff ...
      data_and_code/                data, metadata, scripts, renv.lock
      data_and_code.zip             for Zenodo or Dryad

Its sibling for the journal is
[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md),
[below](#submitting-to-a-journal), and the two differences are the whole
point. The manuscript comes out as **one signed PDF**, not a blinded
pair of Word files: a preprint is not reviewed blind, and hiding the
authors would defeat the reason for posting it. And there is no cover
letter, because there is no editor to address.

Everything else is the same machinery — standalone figures, the
compendium, the lockfile — because a deposit has to stand on its own
exactly as hard as a submission does. The `README.md` it leaves behind
lists what still depends on you, starting with the one that catches
people out: **deposit the data first**. You need its DOI to cite in the
manuscript, and a preprint edited after posting is a new version, not a
correction.

Its arguments are those of
[`make_submission()`](#submitting-to-a-journal), less `blind`, with
other defaults where a preprint differs:

| Argument | Default | What it decides |
|----|----|----|
| `label` | `"bioRxiv"` | Names the folder inside `submission/` and every file in it |
| `line_numbers` | `TRUE` | Numbers every line of the manuscript, continuously, as in a submission: what readers cite in their comments. `FALSE` leaves them unnumbered |
| `line_spacing` | `NULL` | `NULL` keeps the `linestretch` of the `pdf:` format in `_quarto.yml` (1.5 in the template); `1`, `1.5` or `2` set it for this call |
| `suppl_line_spacing` | `NULL` | The same, for the supplement |
| `journal`, `caption_style`, `figure_format`, `snapshot`, `suppl_figures` | as in [`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md) |  |

### Reserving the DOI on Zenodo

The data availability statement needs the DOI of the deposit before the
deposit is published.
[`deposit_zenodo()`](https://danielsangarci.github.io/easypaper/reference/deposit_zenodo.md)
gets it: it uploads `data_and_code.zip` to a new Zenodo deposit,
describes it from the manuscript — title (the short title when there is
one), authors with their affiliations and ORCID, keywords, CC BY 4.0 —
reserves its DOI, and writes it wherever the text says
`10.5281/zenodo.XXXXXXX` and into the cover letters of `submission/`,
where they say `[repository DOI]`. It never publishes: the deposit stays
a draft until you review it on Zenodo and press Publish there. Called
again after the data changed, it replaces the file of the same draft.

``` r

make_preprint()                     # builds data_and_code.zip (or make_submission())
deposit_zenodo(sandbox = TRUE)      # try it on Zenodo's sandbox first
deposit_zenodo()                    # the real draft, and its DOI
```

It is optional, and needs two things only when you use it: the curl
package, and a personal access token of Zenodo with the scopes
`deposit:write` and `deposit:actions`, kept out of the project in your
`.Renviron` as `ZENODO_TOKEN` (`ZENODO_SANDBOX_TOKEN` for the sandbox).

### Describing the data

The deposit carries a description of its data, in `data/metadata/`, and
it does not have to be typed twice.
[`sync_metadata()`](https://danielsangarci.github.io/easypaper/reference/sync_metadata.md)
runs on every render and fills in what the project already knows: the
title of the manuscript and the keywords written under its abstract
(`**Keywords:** ants, mimicry` in `_sections/01_abstract.qmd`), the
authors as the creators of the data, and the variable names from the
data files themselves. It only ever adds, so the descriptions and the
units you write by hand are never overwritten — and what no machine can
guess — what each column means, its units, the dates and places the data
cover — stays yours, and
[`edit_metadata()`](https://danielsangarci.github.io/easypaper/reference/edit_metadata.md)
opens an editor for it:

``` r

edit_metadata("attributes")   # what each column means, and its units
edit_metadata("biblio")       # what the dataset is, when and where
edit_metadata("write")        # dataspice.json and its web page
```

### Submitting to a journal

``` r

make_submission()                                     # -> submission/JournalofEcology/, double-blind
make_submission(blind = FALSE)                        # signed, for a journal that is not blind
make_submission(label = "JournalofEcology_v2")        # a second version, kept apart
```

That builds, from what is already in the project:

    submission/JournalofEcology/
      cover_letter_JournalofEcology.docx      dated, titled and signed; never overwritten
      CHECKLIST.md                            what still has to be done by hand
      manuscript/
        title_JournalofEcology.docx           title, authors, affiliations; double-blind only
        main_JournalofEcology.docx            the title, then the Abstract on, no names
        supporting_information_*.docx
        figures/Figure_1.tiff ...             600 dpi, renumbered in order
      data_and_code/                          data, metadata, scripts, renv.lock
      data_and_code.zip                       for Zenodo or Dryad
      data_and_code_blinded/                  the same, naming nobody; double-blind only
      data_and_code_blinded.zip               for the reviewers

What it does that a render does not:

|  | [`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md) | [`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md) |
|----|----|----|
| Writes into | `output/` | `submission/<label>/` |
| The manuscript | one file, complete | double-blind (the default): a title page and a main text, as two files. `blind = FALSE`: one signed main text |
| The authors | on the front | double-blind: only on the title page, the main text is built without them. Signed: on the front |
| Line numbers and spacing | as the Word template sets them | numbered and double-spaced by default, or as you ask |
| The supplement | its own file, signed, cited as *Figure S1* from the main text | the same, and without the authors when double-blind |
| The figures | embedded in the document | also on their own, at 600 dpi and renumbered in order |
| Data and code | — | the compendium and its `.zip`, `renv.lock` included; double-blind, also a copy that names nobody, for the reviewers |
| Also writes | — | a cover letter, dated, with the title and the corresponding author’s signature, and a `CHECKLIST.md` |
| `renv.lock` | rewritten, to describe this render | rewritten, and copied into the compendium |

| Argument | Default | What it decides |
|----|----|----|
| `journal` | the manuscript’s own | The `.csl` the citations come out in, from `manuscript.qmd` unless you name one |
| `label` | the journal’s name | Names the folder inside `submission/` and every file in it. Left alone it is the journal’s own name with the spaces taken out, so `"ecology-letters"` lands in `submission/EcologyLetters/`. Pass your own for a second version, or for a trial you want to keep apart: `label = "JournalofEcology_v2"` lands in `submission/JournalofEcology_v2/`, beside the first one |
| `caption_style` | `"default"` | As in the renders |
| `figure_format` | `"tiff"` | The standalone figures the journal uploads: `"tiff"`, `"png"` or `"jpg"`. TIFF unless they say otherwise — JPEG is lossy and poor for line art |
| `blind` | `TRUE` | Splits title page from main text the way double-blind review asks: the main text opens with the title alone, the author block is dropped and so are the affiliations, so no name travels in it. `FALSE` when the journal wants them in: one signed main text, and no title page, which would only repeat it |
| `snapshot` | `TRUE` | Runs [`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html) first, so the `renv.lock` that travels in the compendium describes the environment *this* submission came out of. The renders record it too, but a submission is the one you will be asked about. `FALSE` if you keep the lockfile by hand |
| `suppl_figures` | `"separate"` | Whether the supplementary figures and tables go out on their own or at the end of the main text. Either way they are cited from the main text |
| `line_numbers` | `TRUE` | Numbers every line of the main text and the title page, continuously: what reviewers cite. `FALSE` for a journal that does not want them |
| `line_spacing` | `2` | The line spacing of the main text and the title page: `1`, `1.5` or `2` |
| `suppl_line_spacing` | `1.5` | The line spacing of the supplement: `1`, `1.5` or `2`. Its lines are never numbered |

``` r

make_submission(line_numbers = FALSE, line_spacing = 1.5)
make_submission(figure_format = "png", suppl_figures = "main")
```

**Double-blind.** The split into title page and main text is what
double-blind review asks for. The names cannot leak into the main text
because it is not built with them: the author block and the affiliations
are dropped, and the sections that identify you — acknowledgements,
CRediT, conflict of interest, data availability, the list
`blinded-sections:` sets in `_quarto.yml` — move to the title page.
Their citations come out there as the journal prints them, and what only
they cite stays in the reference list of the main text, the paper’s one
list. The title does travel, at the head of the document, because that
is what a journal expects to see on an anonymised manuscript. What
cannot be checked for you — self-citations of the kind “in our previous
study (Author et al.)” — is listed in the `CHECKLIST.md`.

**The data and code compendium.** It is signed: `data_and_code.zip` is
the one you deposit, and a deposit names its authors. When the journal
also wants the data at review, a double-blind submission has
`data_and_code_blinded.zip` for the reviewers: the same data and code,
with the authors taken out of everything the package writes into it —
the creators of the metadata (`creators.csv`, `dataspice.json` and its
page), the copyright line of `LICENSE-CODE`, the README, and the authors
and the pages of the packages `renv.lock` records, which restoring it
does not need; easypaper leaves that copy of the lockfile altogether,
since the analysis does not use it and, installed from GitHub, it names
the account it came from. What it does not write, a comment in a script
or a column of the data, it searches: a name, email, ORCID, affiliation
or account of an author still in the copy is reported with the file it
is in, to take out of the project before you run
[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
again. An account is the user part of an author’s email and the owner of
the project’s GitHub repository: a package of your own installed from
GitHub, which renv needs from there to restore it, is reported that way.

The compendium publishes open formats only: what is in `data/`, never
the source `.xlsx`, and only the analysis code, not your authoring
tooling. Its `README.txt` is written from what the folder actually
holds, so it never needs editing.

## Technical details

The reference material: what you look up once, when you need it.

### The arguments of `create_paper()`

| Argument | Default | What it decides |
|----|----|----|
| `path` | — | The directory to create; `~` is expanded. Its last folder is the project’s name, and the `.Rproj` takes that name too |
| `title` | `NULL` | Written into the YAML of `manuscript.qmd`, the one place it lives: the title page and the README’s heading are given it. Quotes and backslashes are escaped, so a LaTeX fragment such as `\textit{Formica}` survives. Left out, the placeholder stays and every render warns until you replace it |
| `authors` | `NULL` | The names in order, as a vector or one comma-separated string. The first is marked corresponding. Affiliations are not guessed: each author gets a placeholder in the `affiliations:` of the YAML |
| `overwrite` | `FALSE` | Whether to write into a directory that already has files in it. `FALSE` refuses, so an existing manuscript is never overwritten by a mistyped path |
| `git` | `TRUE` | Starts a git repository and makes the first commit. Local and private; it has nothing to do with GitHub, which is a later and separate decision |
| `open` | `FALSE` | Opens the new project in RStudio. Outside an RStudio session it says so and creates the project anyway |

### What `convert_data()` does with each file

The path is relative to the project root, or absolute. Each file takes
one of three roads, decided by its extension alone:

| the original | what [`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md) does |
|----|----|
| `.xlsx`, `.xls` | **converts** it, one `.csv` per sheet, through `readxl` |
| `.sav`, `.dta`, `.sas7bdat` | **converts** it, one `.csv` per file, through `haven` |
| anything already open | **copies** it across byte for byte, because converting it would destroy it rather than open it. Text and tables: `.csv` `.tsv` `.txt` `.json` `.geojson` `.xml` `.yml` `.yaml`. Containers: `.parquet` `.nc` `.h5` `.hdf5` `.sqlite` `.db` `.gpkg`. Spatial: `.shp` with its sidecars (`.shx` `.dbf` `.prj` `.cpg` `.sbn` `.sbx` `.qix`), `.kml` `.gml` `.tif` `.tiff` `.asc`. Sequences and trees: `.fasta` `.fa` `.fastq` `.fq` `.nwk` `.tre` |
| anything else | **leaves it where it is and names it on screen** |

That third row is the one that matters, and you can add to it. If your
field uses something it has not heard of, pass the extension for a
single call, or list it under `open-formats:` in the `easypaper:` block
of `_quarto.yml`, and every call copies it from then on:

``` r

convert_data("originals", also = "las")   # LiDAR point clouds, copied too
```

``` yaml
easypaper:
  open-formats: [las, laz]
```

The last row is not a failure, it is the honest answer: a proprietary
instrument file, an ArcGIS project, a photograph of a field notebook.
Nothing can tell whether they belong in the paper, or what “the table”
inside them would even be. Export them yourself and drop the result into
`data/`. Anything you put there by hand is safe: nothing in that folder
is ever deleted, and it travels to the compendium as it is.

A workbook of one sheet keeps its own name (`counts.xlsx` →
`counts.csv`); with several, the sheet name is added and made safe for a
file name (`counts_adults.csv`, `counts_larvae.csv`). Everything lands
flat: subfolders of a source folder are read but not reproduced. When
two originals want the same name — the same file name in two subfolders,
or two sheets whose names differ only in a character a file name cannot
hold — one keeps it and the rest are **refused with a warning saying
which was kept and which was not**, rather than one table quietly
overwriting another. A conversion that loses something — the value and
variable labels of an `.sav` or a `.dta` — says so when it happens.

| Argument | Default | What it decides |
|----|----|----|
| `path` | — | The file or folder to read, relative to the project root or absolute. A folder is read whole, subfolders included. The originals are only ever read |
| `to` | `data/` | Where the results go |
| `overwrite` | `FALSE` | `FALSE` writes only what is missing from `data/` or older than its original, so a file you corrected by hand stays as it is until the original changes. `TRUE` rebuilds the lot |
| `also` | none | Extensions to treat as already open for this call, with or without the dot. For good: list them under `open-formats:` in `_quarto.yml` |

### Scientific names in the references

citeproc cannot tell a scientific name from any other word, so a
reference list comes out with “Pinus halepensis” in roman — and
lowercased too, when pandoc takes the `.bib` for English. Every render
fixes that before Quarto reads the bibliography: the genera and species
in the titles are found, checked against the [GBIF Backbone
Taxonomy](https://doi.org/10.15468/39omei), and set in italics in a copy
of `references/references.bib` that only Quarto sees. Your `.bib` is
only ever read. Nothing is listed by hand:

| In the title | In the reference list |
|----|----|
| Effects of fire on Pinus halepensis | Effects of fire on *Pinus halepensis* |
| Growth of Quercus ilex subsp. ballota and Q. suber | Growth of *Quercus ilex* subsp. *ballota* and *Q. suber* |
| Leaf traits of Quercus spp. in northern China | Leaf traits of *Quercus* spp. in northern China |
| Wolbachia infections in mosquitoes from Peru | *Wolbachia* infections in mosquitoes from Peru |
| Helicobacter Pylori Infection Control | *Helicobacter pylori* Infection Control |

China, Peru and the Andes are animal genera in GBIF, and stay in roman:
a word that stands on its own is only taken for a genus when Wikipedia
describes it as one. Journal names are never touched, even the ones
named after a genus (*Oryx*, *Ibis*). The titles keep the capitals they
have in the `.bib`, in any style.

What the title alone cannot settle — a genus that is also an English
common name (“Gorilla Conservation in Africa”), a word with several
meanings (“Iris”), a binomial GBIF does not list — is left in roman and
reported, with the line to edit and what to write there:

      * adams2020 (references.bib, line 49): "Gorilla" is also an English common name
          Title: Gorilla Conservation in Central Africa
          If it is the genus, change Gorilla to  \textit{Gorilla}
          If it is not,       change Gorilla to  \textup{Gorilla}

The mark affects that reference only, and a marked word is not reported
again.

Every answer from GBIF and Wikipedia is kept in
`references/species_cache.rds`, so only a name never seen before needs a
connection: the first render of a hundred new references takes a couple
of minutes, the next ones no time at all. **Commit that file**: with it
the italics come out the same on every computer, offline, and years from
now, however GBIF and Wikipedia change. Without a connection nothing
fails — the names that could not be checked stay in roman and a warning
says so — and the next render online completes it. Delete the file to
have every name looked up again. To turn the whole thing off, set
`italicize-species: false` in the `easypaper:` block of `_quarto.yml`.
The live
[`preview()`](https://danielsangarci.github.io/easypaper/reference/render.md)
shows the `.bib` as it is;
[`render_html()`](https://danielsangarci.github.io/easypaper/reference/render.md)
and every document for someone else have the italics.

The same function works on any bibliography, outside a project:

``` r

# in the first chunk of any .qmd or .Rmd, which runs before pandoc reads it
easypaper::italicize_species("references.bib", "references_italic.json")
```

with `bibliography: references_italic.json` in its YAML. It reads a
`.bib` or a CSL-JSON (Zotero’s export);
[`?italicize_species`](https://danielsangarci.github.io/easypaper/reference/italicize_species.md)
has the rest.

### Settings

What a project wants done differently goes in the `easypaper:` block at
the end of its `_quarto.yml`. Quarto ignores it; easypaper reads it on
every call, and it travels with the project, so a setting made once
holds on every computer the paper is rendered on. Every setting is
optional:

``` yaml
easypaper:
  created: "0.1.0"              # written by create_paper()
  italicize-species: true       # false: the references as they are
  blinded-sections:             # what a double-blind submission moves
    - Acknowledgements          #   to the title page
    - CRediT authorship contribution statement
    - Conflict of Interest Statement
    - Data availability statement
  open-formats: []              # more extensions convert_data() copies
  caption-styles:               # your own, for caption_style = "custom"
    custom: {fig: "Fig.", tbl: "Tab.", sfig: "Fig. S", stbl: "Tab. S", delim: ":"}
  trackdown-folder: ""          # the Google Drive folder of td_upload()
```

A section added to `blinded-sections` needs nothing else: the title page
is built from the manuscript, with the sections in the order of that
list. A project that wants more on its title page — a word count, the
number of figures and tables — writes a `title_page.qmd` with it, and
that file is used as the page: the affiliations go where it writes
`<!-- affiliations -->`, each section under its heading if it has one.

### How figures and tables are named

Every journal writes the start of a caption its own way: *Figure 1.*,
*Figure 1:*, *Fig. 1.*, *Fig. 1:*, *Figure 1 \|*. Four things decide it,
and all four come together wherever you set them:

| What | Key in `crossref:` | Key in `caption-styles:` | Example |
|----|----|----|----|
| The word of a figure, in its caption and where the text cites it | `fig-title`, `fig-prefix` | `fig` | `"Figure"`, `"Fig."` |
| The word of a table, in its heading and where the text cites it | `tbl-title`, `tbl-prefix` | `tbl` | `"Table"`, `"Tab."` |
| The same in the supplement, with the S | `reference-prefix` of `sfig` and `stbl` | `sfig`, `stbl` | `"Figure S"`, `"Fig. S"` |
| What follows the number, for figures and tables alike | `title-delim` | `delim` | `"."`, `":"`, or a space and a vertical rule |

For figures and tables, side by side:

| Figure caption | `fig-title` | Table heading | `tbl-title` | `title-delim` |
|----|----|----|----|----|
| *Figure 1.* … | `"Figure"` | *Table 1.* … | `"Table"` | `"."` (a new project) |
| *Figure 1:* … | `"Figure"` | *Table 1:* … | `"Table"` | `":"` |
| *Fig. 1.* … | `"Fig."` | *Tab. 1.* … | `"Tab."` | `"."` |
| *Fig. 1:* … | `"Fig."` | *Tab. 1:* … | `"Tab."` | `":"` |
| *Figure 1* followed by a vertical rule | `"Figure"` | *Table 1*, the same | `"Table"` | a space and a vertical rule |

The word is set apart for figures (`fig-title`) and for tables
(`tbl-title`), so *Fig. 1.* can go with *Table 1.*. The delimiter is
one, `title-delim`, for both: Quarto has no `tbl-delim`, so a figure and
a table always end their number the same way.

The text cites with the same word and no delimiter: with `fig: "Fig."`
and `delim: ":"`, the caption reads *Fig. 1: Ordination of…* and the
text *as shown in Fig. 1*. There is always a space between the word and
the number, except after the S of the supplement (*Fig. S1*): Quarto
writes no *Fig1*.

There are two places to set them, for two different needs.

**For the paper, once: the `crossref:` block of `_quarto.yml`.** This is
what the paper looks like by default:
[`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md),
[`render_pdf()`](https://danielsangarci.github.io/easypaper/reference/render.md),
[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
and
[`preview()`](https://danielsangarci.github.io/easypaper/reference/render.md)
all follow it. A new project writes *Figure 1.* and *Table 1.*; for a
journal that wants *Fig. 1:*, change it to:

``` yaml
crossref:
  fig-title: "Fig."       # the caption of a figure:  "Fig. 1: ..."
  tbl-title: "Table"      # the heading of a table:   "Table 1: ..."
  fig-prefix: "Fig."      # in the text: @fig-nmds -> "Fig. 1"
  tbl-prefix: "Table"     # in the text: @tbl-community -> "Table 1"
  eq-prefix: "Eq."
  title-delim: ":"        # what follows the number: "." ":" " |"
  custom:
    - kind: float
      key: sfig
      reference-prefix: "Fig. S"     # the supplement: "Fig. S1"
      latex-env: sfig
      space-before-numbering: false
    - kind: float
      key: stbl
      reference-prefix: "Table S"    # the supplement: "Table S1"
      latex-env: stbl
      space-before-numbering: false
      caption-location: top
```

Leave the other lines of the block as they are:
`space-before-numbering: false` is what keeps the S and the number
together.

**For one render: `caption_style`.** To see the manuscript as another
journal would print it, or to send it to two journals that want
different things, name a style in the call. Nothing in `_quarto.yml`
changes:

``` r

render_docx(caption_style = "abbrev")              # Fig. 1. / Table 1.
make_submission("ecology-letters", caption_style = "colon")
```

The package comes with five, ready to use in any project:

| `caption_style` | Figure | Table | Supplement |
|----|----|----|----|
| `"default"` | what `crossref:` says: *Figure 1.* in a new project | *Table 1.* in a new project | *Figure S1.*, *Table S1.* in a new project |
| `"abbrev"` | *Fig. 1.* | *Table 1.* | *Fig. S1.*, *Table S1.* |
| `"colon"` | *Figure 1:* | *Table 1:* | *Figure S1:*, *Table S1:* |
| `"compact"` | *Fig. 1:* | *Table 1:* | *Fig. S1:*, *Table S1:* |
| `"nature"` | *Figure 1 \|* | *Table 1 \|* | *Figure S1 \|*, *Table S1 \|* |

These are the captions. The text cites with the same word and no
delimiter: *Fig. 1*, *Table S1*. `"nature"` is named after the journal
that writes its captions that way; the others after what they do.

None of them comes with a journal. The `.csl` of `references/` writes
the citations and the reference list, and nothing about figures or
tables, so `render_docx("ecology-letters")` changes how the paper cites
and leaves its captions as they were. A journal that wants *Fig. 1.*
needs it said here too: in the `crossref:` block, or with
`caption_style` in the same call —
`render_docx("ecology-letters", caption_style = "abbrev")`.

**A style of your own goes under `caption-styles:`**, in the
`easypaper:` block at the end of `_quarto.yml`. It does not exist until
you write it there. Each line is one style: a name, then what it
changes. The template carries this one, commented out:

``` yaml
easypaper:
  caption-styles:
    custom: {fig: "Fig.", tbl: "Tab.", sfig: "Fig. S", stbl: "Tab. S", delim: ":"}
```

``` r

render_docx(caption_style = "custom")   # Fig. 1: ... / Tab. 1: ... / Fig. S1: ...
```

`custom` is only a name. Any other works, and a project can have as many
styles as it needs, one per line — one for each journal you send papers
to, say, named after it.

A style writes only what it changes. Its keys are the ones of the table
at the top of this section, and each one it leaves out is taken from the
`crossref:` block. So in a new project

``` yaml
    figs: {fig: "Fig.", sfig: "Fig. S"}
```

writes *Fig. 1.* and *Fig. S1.*, and keeps *Table 1.*, *Table S1.* and
the full stop from `crossref:`. Give `sfig` whenever you give `fig`, and
`stbl` whenever you give `tbl`: a style with only `fig: "Fig."` writes
*Fig. 1* in the main text and *Figure S1* in the supplement.

A name already in the package — `"abbrev"`, say — is replaced by yours.
A name that is in neither stops the render and lists the ones there are:

    Unknown caption style: 'custom'. Available: default, abbrev, colon,
    compact, nature. Add your own under `caption-styles:` in the easypaper:
    block of _quarto.yml.

### Keeping a project up to date

A fix in easypaper reaches every project with
[`update.packages()`](https://rdrr.io/r/utils/update.packages.html): the
functions live in the package, not in the project. The project keeps
only what is the paper’s, and `renv.lock` records the version of
easypaper that built each document, with every other package — so
[`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
brings back the one a paper was built with, years later. The data and
code compendium the reader downloads carries the analysis and that
lockfile, and reproduces the results without easypaper at all.

### Requirements

R \>= 4.1 and Quarto, which ships inside RStudio and Positron — nothing
to install if you use either. Rendering the PDF also needs a LaTeX
installation
([`tinytex::install_tinytex()`](https://rdrr.io/pkg/tinytex/man/install_tinytex.html)
is enough). The R packages a project needs for every step — rendering,
figures, the data deposit’s metadata, converting spreadsheets — are
installed together with easypaper. The one exception is `trackdown`, for
[co-authors in Google Docs](#writing-with-co-authors), which has to come
from GitHub. Two more are needed only by the function that uses them:
vegan by
[`create_example_paper()`](https://danielsangarci.github.io/easypaper/reference/create_example_paper.md),
which offers to install it, and curl by
[`deposit_zenodo()`](https://danielsangarci.github.io/easypaper/reference/deposit_zenodo.md).

### Known traps

- **knitr runs chunks and inline code inside HTML comments**
  (`<!-- -->`). To disable a chunk use `#| eval: false`, never comment
  it out.
- **Google Drive corrupts git repositories** by syncing `.git/` file by
  file. Keep projects outside the Drive folder and sync through GitHub.
  For co-authors there is
  [`td_upload()`](https://danielsangarci.github.io/easypaper/reference/trackdown.md),
  which uploads plain text only.
- **The knitr cache does not notice changes in data files.** After
  touching `data/`, run
  [`clean_cache()`](https://danielsangarci.github.io/easypaper/reference/clean_cache.md).
- **`~/.Rprofile` is loaded in every R session.** If the manuscript uses
  something defined there without you noticing, it will not reproduce on
  another machine. When in doubt:
  `R --vanilla -e 'easypaper::render_all()'`.
- **renv does not capture Quarto.** It is an external binary.
  [`export_code()`](https://danielsangarci.github.io/easypaper/reference/export_code.md)
  records its version in `output/sessionInfo.txt`; put it in the Data
  availability statement too.
- **Table captions are written by Quarto** (`#| tbl-cap`). Do not also
  use
  [`flextable::set_caption()`](https://davidgohel.github.io/flextable/reference/set_caption.html)
  or they come out twice.
- **The first PDF render installs LaTeX packages** through `tlmgr`, and
  the first time it may fail while `tlmgr` updates itself. Run it again
  and it goes through. It needs a connection.

### Licences

A research compendium mixes code and scientific content, which are not
licensed the same way: the code — `R/*.R` and the chunks of the sections
— is MIT (`LICENSE-CODE`), and the text, figures, tables and data are CC
BY 4.0 (`LICENSE`). Nothing has to be filled in by hand:
[`sync_licenses()`](https://danielsangarci.github.io/easypaper/reference/sync_licenses.md),
which every render runs, reads the authors from the YAML of
`manuscript.qmd` and writes them into the copyright line of
`LICENSE-CODE` and into the notice at the end of the project’s
`README.md`. `LICENSE` is never touched: Creative Commons asks that the
text of its licences not be modified, and CC BY is applied by marking
the work, which is what that notice does.

CC BY rather than CC0 for the data, because it makes attribution a legal
obligation — and in the EU it also covers the *sui generis* database
right. Dryad publishes everything under CC0 whatever the files say; if a
journal sends you there, deposit anyway and say so in the Data
availability statement.

### Citing easypaper

``` r

citation("easypaper")
```

The BibTeX entry carries the key `easypaper`, so it drops into a `.bib`
as it is. GitHub’s *Cite this repository* button reads `CITATION.cff`,
which holds the same details and the ORCID.

The paper you write cites its own tooling without your help: the last
chunk of `manuscript.qmd` runs
[`knitr::write_bib()`](https://rdrr.io/pkg/knitr/man/write_bib.html)
over the packages in play — easypaper among them — into
`references/packages.bib`, so `[@R-easypaper]` resolves on every render.
Where to put that citation is a question of its own, and the comment at
the top of `_sections/09_data_availability.qmd` answers it:
infrastructure is cited where you report the deposit, not in Methods
among the packages that produced the results.

### Where to read more

[`?easypaper`](https://danielsangarci.github.io/easypaper/reference/easypaper-package.md)
lists every function, and each has a help page with its arguments
explained. The project’s own `README.md` is short and yours: it says how
the paper is built and carries its licence notice.
