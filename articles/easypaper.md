# Getting started with easypaper

A scientific paper is not one document. It is text, analyses, figures,
tables, a bibliography, supplementary material, and — when the time
comes — a blinded manuscript, a title page, figures at the resolution
the journal demands, and a data deposit. easypaper writes that whole
structure in one call, and then gets out of the way.

## Creating a project

``` r

library(easypaper)

create_paper("~/papers/ant_chemistry",
             title   = "Chemical mimicry in Maculinea rebeli",
             authors = c("Daniel Sanchez-Garcia", "Second Author"))
```

In RStudio the same thing is **File \> New Project \> New Directory \>
Reproducible Quarto manuscript**, with fields for the title and the
authors.

The title and the authors are optional; without them the YAML keeps its
placeholders, and `make.R` warns you about them until you replace them.
The affiliation marks are embedded in the names (`First Author^1,\*^`)
because Quarto rebuilds the author line of a `.docx` and drops any
structured affiliation — the affiliations themselves live in
`_sections/0_authors.qmd`.

Here is what lands on disk:

``` r

dir <- file.path(tempdir(), "demo_paper")
easypaper::create_paper(dir, git = FALSE)
#> Project created: /tmp/RtmpajbZx8/demo_paper
#>   1. open demo_paper.Rproj
#>   2. source("make.R")
#>   3. render_html()      # or see run.R for every command

fs <- list.files(dir, recursive = FALSE, all.files = TRUE, no.. = TRUE)
sort(fs)
#>  [1] "_quarto.yml"       "_sections"         ".gitignore"       
#>  [4] "cache"             "data"              "demo_paper.Rproj" 
#>  [7] "figures"           "format"            "LICENSE"          
#> [10] "LICENSE-CODE"      "make.R"            "manuscript.qmd"   
#> [13] "output"            "R"                 "README.md"        
#> [16] "references"        "references_styles" "run.R"            
#> [19] "supplementary.qmd" "title_page.qmd"
```

``` r

sort(list.files(file.path(dir, "_sections")))
#>  [1] "0_authors.qmd"        "1_abstract.qmd"       "2_introduction.qmd"  
#>  [4] "3_methods.qmd"        "4.1_results1.qmd"     "4.2_results2.qmd"    
#>  [7] "5_discussion.qmd"     "6_figures.qmd"        "7_tables.qmd"        
#> [10] "8_suppl_material.qmd"
```

## The anatomy

`manuscript.qmd` holds no prose. It is a spine: the YAML with title and
authors, and a list of includes in reading order.

    {{< include _sections/2_introduction.qmd >}}
    {{< include _sections/3_methods.qmd >}}
    {{< include _sections/4.1_results1.qmd >}}

The number in front of each file is **the section of the paper**, not a
sequence: Results split in two is `4.1` and `4.2`, exactly as you would
number them in the text. Nothing depends on the alphabetical order of
the files — the build order is the order of those includes, and `make.R`
reads it from there.

Everything else follows one rule: **paths are relative to the project
root**, in the YAML and in the R code alike. `_quarto.yml` sets
`execute-dir: project`, so a chunk runs with the working directory at
the root, and `here::here()` resolves the same way.

Where each thing goes, then:

|  |  |
|----|----|
| `_sections/*.qmd` | The text. This is where you write |
| `data/raw/` | The originals, as they arrived. Read only, never edited |
| `data/csv/` | The same data in open format, written by `sync_data()`. **This is what gets published** |
| `R/setup.R` | Seed, palette, table and figure helpers |
| `references/references.bib` | The bibliography you cite from |
| `references_styles/*.csl` | One citation style per journal |
| `format/` | Three Word templates: the manuscript (line-numbered, ragged right), the supplement and the cover letter (both justified, neither numbered) |
| `figures/`, `output/`, `cache/` | Produced by the render. Regenerable, and in `.gitignore` |
| `submission/` | Built by `make_submission()`. Never edited by hand |

Two of those deserve the emphasis. `data/raw/` is read-only on purpose:
the file that came off the instrument, or out of a collaborator’s mail,
is the one thing a reproducible project cannot regenerate. And
everything under `output/` and `figures/` is disposable by design — if
deleting it makes you nervous, something is being done by hand that
should be done by code.

## The data folder

Three folders, and what separates them is not tidiness: it is what gets
published.

    data/raw/       the originals, exactly as they arrived. Read only, never
                    edited, never published
    data/csv/       the same data in an open format. THIS is what the deposit
                    carries and what the metadata describes
    data/metadata/  the dataspice description of the above

One call keeps the second in step with the first:

``` r

source("R/sync_data.R")
sync_data()
```

It converts every spreadsheet in `raw/` sheet by sheet, copies across
whatever is already plain text, and **names whatever it could not read**
— a `.sqlite`, a GeoPackage, a NetCDF. Those never reach the deposit
unless you put a copy in `data/csv/` yourself, which is allowed and
safe: the folder is not restricted to `.csv` despite its name, nothing
there is ever deleted, and a file you place by hand travels to the
compendium exactly as it is.

Two rules follow, and they are the ones worth holding onto:

**Read from `data/csv/`, never from `data/raw/`.** An analysis that
reads the originals works perfectly on your machine and publishes a
compendium with no data in it — and nothing would have told you.

**`data/csv/` is not “my clean data”.** It is the same data in an open
format: a conversion, not a transformation. Filtering, recoding and
excluding individuals belong in the chunk that needs them, where a
reviewer can read the decision, never as a derived file nobody can
trace. `check_data()` reports what is sitting in there that the analysis
never reads — it travels to the repository all the same.

## Writing

The order of a first day, once the project exists:

1.  Open the `.Rproj`, then `source("make.R")`.
2.  Fill in the affiliations in `_sections/0_authors.qmd`. The names are
    already there if you passed `authors`, with their marks in place.
3.  Write. `_sections/2_introduction.qmd` is plain markdown: headings
    and paragraphs, nothing to declare.
4.  Put the originals in `data/raw/` and run `sync_data()`. It converts
    every spreadsheet sheet by sheet and copies across whatever is
    already plain text, into `data/csv/`. Read from **there**, with the
    path relative to the project root: `data/raw/` never travels to the
    deposit, so an analysis that reads from it would publish a
    compendium with no data in it.
5.  `render_html()` whenever you want to look at it. Seconds, not
    minutes.

From there it is one loop — write, render, repeat — and the analysis
lives inside the section that reports it:

    ```{r}
    #| label: richness-model
    #| cache: true
    richness <- readr::read_csv(here::here("data/csv/richness.csv")) |>
      dplyr::filter(!is.na(S), status != "dead")

    m1 <- glmmTMB::glmmTMB(S ~ treatment + (1 | plot),
                           family = nbinom2, data = richness)
    ```

    Richness was higher in the treatment
    (beta = r round(fixef(m1)$cond[2], 2)), as shown in @fig-richness.

Cleaning happens there, from the input `.csv`, never as a derived file
saved in `data/`. Excluding individuals or recoding a factor is a
scientific decision: it belongs in code a reader can check, not in a
spreadsheet nobody can trace. `#| cache: true` covers the cost of
recomputing it.

## Rendering

Two different jobs live in this project, and the function names make
more sense once they are told apart. **Rendering** produces documents to
read: one file each, complete, with the authors on the front, written
into `output/`. You will do it a hundred times. **Submitting** builds
the package a journal asks for — blinded, split in two, figures as
separate files, the data and code compendium — written into
`submission/`. You will do it twice.

This section is the first job.

``` r

source("make.R")

render_html()                       # seconds, while you write
render_docx("myrmecological-news")  # the .docx, in that journal's style
render_pdf()                        # the .pdf, for a preprint server
make_all()                          # the four below, in order
```

| Command | What comes out | Where |
|----|----|----|
| `render_html()` | the working `.html`, images embedded | `output/` |
| `render_docx()` | the `.docx`, with the journal’s citation style and Word template | `output/journal/` |
| `render_pdf()` | the `.pdf` for bioRxiv or EcoEvoRxiv | `output/preprint/` |
| `render_supplementary()` | the supplement on its own, with its own reference list | `output/supplementary/` |
| `export_code()` | `analysis_code.R` and `sessionInfo.txt` | `output/supplementary/` |
| `preview()` | a live `.html` that reloads every time you save | — |
| `make_all()` | the four: journal, preprint, supplement, code | `output/` |

The prefixes are a convention, and worth reading once: **`render_`** is
one call to Quarto and one document, into `output/`. **`make_`** is a
deliverable assembled from several steps — a batch, or a folder — and
they are the targets of `make.R`, which is a Makefile written in R.
**`export_`** derives a file without going through Quarto. And
**`check_`** looks and warns, but never writes: that promise is why
recording the environment is not something a `check_` does. In short:
`render_` makes a document, `make_` makes a deliverable, `check_` makes
nothing.

Every one of those except `render_html()` records `renv.lock` when it
finishes: a document somebody else will read carries the environment it
came out of, and it costs about three tenths of a second. The `.html` is
left out on purpose — it is the loop you run every two minutes, and it
is also what you render after restoring an old environment to look into
a reviewer’s complaint, where overwriting your record is the last thing
you want. The lockfile is only rewritten when the environment really
moved, so most renders leave it alone and say nothing.

Two things about `make_all()` that its name does not tell you. It leaves
out `render_html()`, because the `.html` is the one you run while
writing and it would only slow down the batch. And **it does not build a
submission**: that is `make_submission()`, it writes somewhere else
entirely, and it is deliberately not part of any “do everything”
shortcut — the reason is in [Submitting](#submitting).

The journal is an argument, not an edit: nothing in the `.qmd` files
changes when you send the same paper somewhere else. Of the four
arguments below, `render_html()` and `make_all()` take the first two;
`render_docx()` and `render_pdf()` take all four.

| Argument | Default | What it decides |
|----|----|----|
| `journal` | `"myrmecological-news"` | Which `.csl` in `references_styles/` sets the citation style. `list_journals()` lists the ones you have |
| `caption_style` | `"default"` | How a caption is written: `"default"` gives *Figure 1.*, `"abbrev"` gives *Fig. 1.*, `"nature"` gives *Figure 1* followed by a vertical rule, `"compact"` gives *F1:* |
| `split` | `FALSE` | The supplement is *always* rendered on its own, which is the only way it can carry its own reference list. `split` decides what you get back: `FALSE` merges the two into the single file you circulate, `TRUE` leaves them as two, which is what a journal wants. `make_submission()` always uses `TRUE` |
| `suppl_figures` | `"separate"` | Whether the supplementary figures and tables travel with the supplement or stay at the end of the manuscript. Either way they are cited from the main text |

One warning you will meet, and it is worth reading once. Merging a
`.pdf` costs nothing: `qpdf` concatenates pages, so what Quarto composed
arrives untouched. Merging a `.docx` is another matter — pandoc
*rebuilds* the document rather than copying it. Text, figures, tables
and merged cells survive; **what a table drew for itself does not**.
Cell shading and custom borders are dropped, and the tables fall back on
the Word template’s `Table` style, which for that reason carries the
three rules a scientific table wants: above, under the header row, and
below. Nothing you submit is ever merged, so this only affects the copy
you circulate; `split = TRUE` gives you two files with every table
exactly as flextable drew it.

Two more exist for the supplement alone: `render_supplementary()` takes
`output_format` (`"docx"` by default) and `files`, a subset of the
supplementary documents — which is how `make_submission()` renders only
the supplementary *text* when the figures are staying in the main
document.

`run.R`, inside the project, lists every command with each argument
explained, ready to run one line at a time. It is the file to open when
you cannot remember a name.

## Supplementary material

Two kinds, told apart by what the file contains — nothing to declare:

- **Figures and tables**: any `_sections/8*suppl*.qmd` defining an
  `sfig` or `stbl` div. They are numbered `Figure S1`, `Table S1`, on a
  counter of their own, so a supplementary figure never advances the
  numbering of `Figure 1`.
- **Text** (an extended Methods, say): a supplementary file with no
  floats. It always leaves as its own document, which is the point — its
  reference list is independent from the main text’s.

Where the figures end up is decided when you submit, and the citations
work either way:

``` r

make_submission("myrmecological-news")                        # own document
make_submission("myrmecological-news", suppl_figures = "main") # end of the main text
```

## Submitting

`make_submission()` is not the last step of `make_all()`, and that is on
purpose. A render is cheap and disposable: you run it after every
paragraph. A submission is a moment you will want to return to — it
rewrites `renv.lock` to record the environment this exact version came
out of, and it stamps a label on every file it writes. Folding that into
a “build everything” command would mean rewriting your dependency
manifest every time you fixed a typo.

What it does that a render does not:

|  | `render_docx()` | `make_submission()` |
|----|----|----|
| Writes into | `output/journal/` | `submission/<label>/` |
| The manuscript | one file, complete | title page and main text, as two files |
| The authors | on the front | only on the title page; the main text is built without them |
| The supplement | inside the document | its own file, cited as *Figure S1* from the main text |
| The figures | embedded in the document | also on their own, at 600 dpi and renumbered in order |
| Data and code | — | the compendium and its `.zip`, `renv.lock` included |
| Also writes | — | a cover letter and a `CHECKLIST.md` |
| `renv.lock` | rewritten, to describe this render | rewritten, and copied into the compendium |

``` r

make_submission("myrmecological-news")                        # -> submission/default/
make_submission("myrmecological-news", label = "MyrmecologicalNews") # the real submission
```

| Argument | Default | What it decides |
|----|----|----|
| `journal` | `"myrmecological-news"` | The `.csl` the citations come out in |
| `label` | `"default"` | Names the folder inside `submission/` and every file in it. The default is deliberate: a trial run is then unmistakably a trial, and never carries the name of a journal you did not choose |
| `caption_style` | `"default"` | As in the renders above |
| `figure_format` | `"tiff"` | The standalone figures the journal uploads: `"tiff"`, `"png"` or `"jpg"`. TIFF unless they say otherwise — JPEG is lossy and poor for line art |
| `blinded` | `TRUE` | Splits title page from main text the way double-blind review asks: the title block is dropped and `0_authors.qmd` is left out, so no name travels in the main text. `FALSE` when the journal wants them in |
| `snapshot` | `TRUE` | Runs `renv::snapshot()` first, so the `renv.lock` that travels in the compendium describes the environment *this* submission came out of. The renders record it too, but a submission is the one you will be asked about. `FALSE` if you keep the lockfile by hand |
| `suppl_figures` | `"separate"` | Whether the supplementary figures and tables go out on their own or at the end of the main text. Either way they are cited from the main text |

That builds, from what is already in the project:

    submission/default/
      cover_letter_default.docx               template, never overwritten
      CHECKLIST.md                            what still has to be done by hand
      manuscript/
        title_default.docx                    title, authors, affiliations, counts
        main_default.docx                     from the Abstract on, with no names
        supporting_information_*.docx
        figures/Figure_1.tiff ...             600 dpi, renumbered in order
      data_and_code/                          data, metadata, scripts, renv.lock
      data_and_code.zip                       for Zenodo or Dryad

The split into title page and main text is what double-blind review asks
for. The names cannot leak into the main text because it is not built
with them: the title block is dropped and the authors section is left
out. What is *not* checked for you — acknowledgements, CRediT, and
self-citations of the kind “in our previous study (Author et al.)” — is
listed in the `CHECKLIST.md`.

The compendium publishes open formats only: the `.csv`, never the source
`.xlsx`, and only the analysis code, not your authoring tooling. Its
`README.txt` is written from what the folder actually holds, so it never
needs editing.

Nor does its metadata have to be typed twice. `sync_metadata()` runs on
every render and fills in what the project already knows: the title and
the keywords from the manuscript, the authors as the creators of the
data, and the variable names from the data files themselves. It only
ever adds, so the descriptions and the units you write by hand are never
overwritten — and what no machine can guess, the coverage and the
licence of the deposit, stays yours.

## The preprint deposit

A preprint goes to two places at once — the manuscript to a server, the
data and code to a repository — and `make_preprint()` builds both halves
into `submission/bioRxiv/`.

``` r

make_preprint()                       # -> submission/bioRxiv/
make_preprint(label = "EcoEvoRxiv")   # another server
make_preprint(label = "bioRxiv_v2")   # the revised version
```

    submission/bioRxiv/
      README.md                     what goes to the server, what to the repository
      manuscript/
        preprint_bioRxiv.pdf        the manuscript, signed
        supporting_information_bioRxiv.pdf
        figures/Figure_1.tiff ...
      data_and_code/                data, metadata, scripts, renv.lock
      data_and_code.zip             for Zenodo or Dryad

It is `make_submission()`’s sibling, and the two differences are the
whole point. The manuscript comes out as **one signed PDF**, not a
blinded pair of Word files: a preprint is not reviewed blind, and hiding
the authors would defeat the reason for posting it. And there is no
cover letter, because there is no editor to address.

Everything else is the same machinery — standalone figures, the
compendium, the lockfile — because a deposit has to stand on its own
exactly as hard as a submission does. The `README.md` it leaves behind
lists what still depends on you, starting with the one that catches
people out: **deposit the data first**. You need its DOI to cite in the
manuscript, and a preprint edited after posting is a new version, not a
correction.

## The checks

Every render runs them, and you can call them yourself:

``` r

check_citations()   # @keys with no entry in references/, and the reverse
check_crossrefs()   # @fig-/@tbl- with no target, and figures nobody cites
check_title()       # has title_page.qmd drifted from the manuscript?
check_renv()        # is renv.lock there, and does it match what you use?
check_data()        # .csv in data/csv/ that the analysis never reads
```

The second one has caught more submissions than the rest together: a
figure defined and never cited is a figure the journal will ask you
about.

## Citing easypaper

``` r

citation("easypaper")
```

The BibTeX entry carries the key `easypaper`, so it drops into a `.bib`
as it is. GitHub’s *Cite this repository* button reads `CITATION.cff`,
which holds the same details and the ORCID.

The paper you write cites its own tooling without your help: the setup
chunk of `manuscript.qmd` runs
[`knitr::write_bib()`](https://rdrr.io/pkg/knitr/man/write_bib.html)
over the packages in play — easypaper among them — into
`references/packages.bib`, so `[@R-easypaper]` resolves on every render.
Where to put that citation is a question of its own, and the master
answers it in a commented block at the end: infrastructure is cited
where you report the deposit, not in Methods among the packages that
produced the results.

## Where to read more

The project’s own `README.md` is the reference: the path rule, the
numbering, the known traps, how the two bibliographies stay independent,
and what to do before submitting. It travels inside every project
easypaper creates.
