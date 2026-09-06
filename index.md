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

source("make.R")
render_html()          # fast, while you write
make_all()             # .docx + .pdf + supplement
make_submission("myrmecological-news")            # -> submission/default/
make_submission("myrmecological-news", label = "MyrmecologicalNews")   # the real one
```

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
    data/raw/            The originals, as they arrived. Read only
    data/processed/      The same data in open format, written by code
    R/setup.R            Seed, palette, table and figure helpers
    references/          The .bib you cite from
    references_styles/   One .csl per journal
    format/              The Word templates the .docx is built on
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
`make.R` records which version of easypaper wrote the structure.

## Requirements

R \>= 4.1 and Quarto, which ships inside RStudio and Positron — nothing
to install if you use either. Rendering the PDF also needs a LaTeX
installation
([`tinytex::install_tinytex()`](https://rdrr.io/pkg/tinytex/man/install_tinytex.html)
is enough).

## Licence

MIT for the code. The template it writes carries MIT for code and CC BY
4.0 for data, which is the pairing most journals and data repositories
expect.
