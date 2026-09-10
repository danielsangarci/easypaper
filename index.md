# easypaper

Creates, in one call, the directory structure of a reproducible
scientific manuscript written in Quarto.

``` r

# install.packages("remotes")
remotes::install_github("danielsangarci/easypaper")

library(easypaper)
create_paper("~/papers/ant_chemistry",
             title   = "Chemical mimicry in Maculinea rebeli",
             authors = c("First Author", "Second Author"))
```

Then open the `.Rproj` it leaves behind and:

``` r

source("make.R")                     # loads every command below
convert_data("originals/counts.xlsx")# bring data in: converted or copied, into data/

# while you write
render_html()                        # the working .html, in seconds
preview()                            # live: reloads every time you save

# the documents, into output/
render_docx("myrmecological-news")   # the .docx, in that journal's style
render_pdf()                         # the .pdf, for a preprint server
render_supplementary()               # the supplement, with its own references
export_code()                        # analysis_code.R + sessionInfo.txt
make_all()                           # the four above, in order

# what you send, into submission/
make_submission("myrmecological-news")                                # a trial run
make_submission("myrmecological-news", label = "MyrmecologicalNews")  # the real one
make_preprint()                                                       # the whole deposit
```

Every render checks first — citations with no entry, cross-references
with no target, data files nobody reads — and records the environment it
came out of. `list_journals()` tells you which citation styles you have,
and `easypaper::add_journal("plos-one")` fetches one the template does
not ship; `check_data()`, `check_renv()` and their siblings can be
called on their own.

`make_all()` renders; `make_submission()` submits. The first writes
documents to read, into `output/`. The second builds what the journal
asks for — blinded, split in two, figures apart, compendium included —
into `submission/`, and is not part of `make_all()`.

`run.R`, inside the new project, lists every command with its arguments
explained, ready to run one line at a time.

The project is also initialised as a **git repository**, with the first
commit already made (`git = FALSE` if you would rather not). That is
local and private, and unrelated to GitHub: it means the manuscript has
a history from its first line. The point comes months later, when
`git tag submission-1` lets you return to the exact state that produced
what you sent, and `git diff submission-1 submission-2 -- _sections/`
writes half of your response to reviewers. Outputs, figures and the
submission folder stay out of it: they are regenerable, and git is poor
with binaries.

In RStudio it is also **File \> New Project \> New Directory \>
Reproducible Quarto manuscript**, with fields for the title and the
authors.

## What the project gives you

- **One source, many outputs.** The text lives in `_sections/*.qmd`;
  `make.R` renders the journal `.docx`, the preprint `.pdf`, a working
  `.html` and the supplement, each with the citation style of the
  journal you name.
- **Preprint deposit.** `make_preprint()` builds the other destination:
  the manuscript as one signed `.pdf`, its supplement, its figures and
  the data and code compendium, ready to split between a preprint server
  and a data repository.
- **Submission folder.** `make_submission()` builds the blinded
  manuscript (title page and main text split the way double-blind review
  asks for), figures at 600 dpi renumbered in order, a cover letter, a
  checklist, and a data-and-code compendium ready for Zenodo or Dryad,
  `renv.lock` included.
- **Supplementary material with independent references.** Supplementary
  figures and tables are numbered `Figure S1`, `Table S1`, cited from
  the main text, and can either travel in their own document or sit at
  the end of the main one. Supplementary *text* always goes out as its
  own document, with its own reference list.
- **Figures in PNG, JPG and TIFF** at 600 dpi, exported on every render.
- **Checks before you send anything**: citations with no entry, cross-
  references with no target, figures nobody cites, a title page that no
  longer matches the manuscript, a missing `renv.lock`.

## What the project looks like

    manuscript.qmd       The spine: title, authors, and the list of includes
    _sections/           The text, one file per section. This is where you write
    data/                The data, in open formats. This is what gets published
    R/setup.R            Seed, palette, table and figure helpers
    references/          The .bib you cite from
    references_styles/   One .csl per journal
    format/              Three Word templates: manuscript, supplement, letter
    figures/  output/    Everything the render produces. Regenerable
    submission/          What make_submission() builds
    make.R               The only entry point
    run.R                Every command, explained, one line at a time

You write in `_sections/`. Everything else is configuration you set
once, or output you never edit by hand.

Each project also carries **its own `README.md`**: the full reference —
the path rule, the numbering convention, the known traps, the licence
pairing, and the checklist before submitting. It travels inside the
project, so it is still there when easypaper is not, and it is the
document to read on the first day.

What every command takes — `journal`, `caption_style`, `split`,
`suppl_figures`, `label`, `figure_format`, `blinded`, `snapshot` — is
laid out with its default in [Get
started](https://danielsangarci.github.io/easypaper/articles/easypaper.html).

## The data folder

`data/` is the folder that publishes: whatever is in it is what the
analysis reads, what the metadata describes and what the submission
compendium carries to the repository. Beside it, `data/metadata/` holds
the [dataspice](https://github.com/ropensci/dataspice) description of
those files.

Your originals live wherever you keep them — the project does not
publish them, so it does not prescribe a place.
[`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
brings a copy in, in a format that will still open in twenty years, and
never touches the original:

``` r

convert_data("originals/counts.xlsx")   # one workbook, one .csv per sheet
convert_data("originals")               # a whole folder at once
convert_data("~/Drive/plots.gpkg")      # already open: copied, not converted
```

The path is relative to the project root, or absolute. Each file takes
one of three roads, decided by its extension alone:

| the original | what [`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md) does |
|----|----|
| `.xlsx`, `.xls` | **converts** it, one `.csv` per sheet (needs `readxl`) |
| `.sav`, `.dta`, `.sas7bdat` | **converts** it, one `.csv` per file (needs `haven`) |
| anything already open | **copies** it byte for byte. Text and tables: `.csv` `.tsv` `.txt` `.json` `.geojson` `.xml` `.yml` `.yaml`. Containers: `.parquet` `.nc` `.h5` `.hdf5` `.sqlite` `.db` `.gpkg`. Spatial: `.shp` with its sidecars (`.shx` `.dbf` `.prj` `.cpg` `.sbn` `.sbx` `.qix`), `.kml` `.gml` `.tif` `.tiff` `.asc`. Sequences and trees: `.fasta` `.fa` `.fastq` `.fq` `.nwk` `.tre` |
| anything else | **leaves it where it is and names it on screen** |

The third row is a list you can edit — `.cd_open_formats`, at the top of
`R/convert_data.R` inside your project — or extend for one call with
`convert_data(path, also = "las")`. The fourth is for what nothing can
place: a proprietary instrument file, an ArcGIS project. Export those
yourself and drop the result into `data/`.

Two rules follow. **Read from `data/`, never from wherever the original
lives** — an analysis that reads the original works on your machine and
publishes a compendium with no data in it, and nothing would have told
you. And **keep the originals**: every conversion costs something, an
`.xlsx` its formulas and an `.sav` its value labels, so the original is
the only answer when a number here looks wrong. `check_data()` lists
what is sitting in `data/` that the analysis never reads.

The function is also exported by the package, so
[`easypaper::convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
works in any project, whether or not easypaper created it.

## Where the code lives

The build logic is **copied into each project**, not kept in this
package. That is deliberate: the submission compendium ships `scripts/`,
and whoever reproduces your analysis should not need easypaper installed
to do it. Once created, a project is self-contained; this package is
only the scaffold.

So there are two moments, and only the first one involves this package.
You call
[`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md)
with easypaper loaded; from then on you work from inside the project,
where `source("make.R")` gives you `render_html()`, `make_all()` and
`make_submission()`. Those functions belong to the project, not to the
package: they keep working with easypaper uninstalled, which is what
makes the compendium you deposit reproducible on its own. The top of
`make.R` records which version of easypaper wrote the structure, and
[`easypaper::update_project()`](https://danielsangarci.github.io/easypaper/reference/update_project.md)
refreshes that build logic from a newer version without touching what
you wrote: `dry_run = TRUE` shows what would change, and the update goes
in as one commit you can read and revert file by file.

## Requirements

R \>= 4.1 and Quarto, which ships inside RStudio and Positron — nothing
to install if you use either. Rendering the PDF also needs a LaTeX
installation
([`tinytex::install_tinytex()`](https://rdrr.io/pkg/tinytex/man/install_tinytex.html)
is enough).

## Citation

``` r

citation("easypaper")
```

> Sanchez-Garcia, D. (2026). easypaper: Scaffold a Reproducible Quarto
> Manuscript Project with Output Ready for Co-Authors, Preprints and
> Journals. R package version 0.2.3.
> <https://github.com/danielsangarci/easypaper>

The BibTeX entry comes with the key `easypaper`, ready to paste into a
`.bib`. GitHub’s *Cite this repository* button reads `CITATION.cff`,
which carries the same details and the ORCID.

## Licence

MIT for the code. The template it writes carries MIT for code and CC BY
4.0 for data, which is the pairing most journals and data repositories
expect.
