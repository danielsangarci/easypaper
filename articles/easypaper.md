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
The affiliation marks are embedded in the names (`Author1^1,\*^`)
because Quarto rebuilds the author line of a `.docx` and drops any
structured affiliation — the affiliations themselves live in
`_sections/0_authors.qmd`.

Here is what lands on disk:

``` r

dir <- file.path(tempdir(), "demo_paper")
easypaper::create_paper(dir, git = FALSE)
#> Project created: /tmp/RtmpaYEm35/demo_paper
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
| `data/` | The data, in open formats. **This is what gets published** |
| `R/setup.R` | Seed, palette, table and figure helpers |
| `references/references.bib` | The bibliography you cite from |
| `references_styles/*.csl` | One citation style per journal |
| `format/` | Three Word templates: the manuscript (line-numbered, ragged right), the supplement and the cover letter (both justified, neither numbered) |
| `figures/`, `output/`, `cache/` | Produced by the render. Regenerable, and in `.gitignore` |
| `submission/` | Built by `make_submission()`. Never edited by hand |

Two of those deserve the emphasis. `data/` is the folder that publishes:
whatever is in it is what the analysis reads, what the metadata
describes and what the deposit carries. And everything under `output/`
and `figures/` is disposable by design — if deleting it makes you
nervous, something is being done by hand that should be done by code.

## The data folder

`data/` is the folder that publishes. Whatever is in it is what the
analysis reads, what `sync_metadata()` describes and what the submission
compendium carries to the repository. A file that is not there does not
reach the deposit. Beside it, `data/metadata/` holds the dataspice
description of those files — the description, not data itself, and it
travels to the deposit as its own folder.

Your originals live wherever you keep them: a folder in the project, a
shared drive, your downloads. The project does not prescribe a place,
because it does not publish them.
[`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
brings a copy in, in a format that will still open in twenty years, and
it **never runs by itself**:

``` r

convert_data("originals/counts.xlsx")   # one workbook, one .csv per sheet
convert_data("originals")               # a whole folder at once
convert_data("~/Drive/plots.gpkg")      # already open: copied, not converted
```

The path is relative to the project root, or absolute. Each file takes
one of three roads, decided by its extension alone:

| the original | what [`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md) does |
|----|----|
| `.xlsx`, `.xls` | **converts** it, one `.csv` per sheet. Needs `readxl` |
| `.sav`, `.dta`, `.sas7bdat` | **converts** it, one `.csv` per file. Needs `haven` |
| anything already open | **copies** it across byte for byte, because converting it would destroy it rather than open it. Text and tables: `.csv` `.tsv` `.txt` `.json` `.geojson` `.xml` `.yml` `.yaml`. Containers: `.parquet` `.nc` `.h5` `.hdf5` `.sqlite` `.db` `.gpkg`. Spatial: `.shp` with its sidecars (`.shx` `.dbf` `.prj` `.cpg` `.sbn` `.sbx` `.qix`), `.kml` `.gml` `.tif` `.tiff` `.asc`. Sequences and trees: `.fasta` `.fa` `.fastq` `.fq` `.nwk` `.tre` |
| anything else | **leaves it where it is and names it on screen** |

That third row is the one that matters, and it is a list you can edit:
it lives in `.cd_open_formats`, at the top of `R/convert_data.R`
**inside your project**. If your field uses something it has not heard
of, add the extension there — or pass it for a single call:

``` r

convert_data("originals", also = "las")   # LiDAR point clouds, copied too
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
overwriting another.

By default
[`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
writes only what is missing from `data/` or older than its original, so
a file you have corrected by hand stays as it is until the original
changes. `convert_data(path, overwrite = TRUE)` rebuilds the lot.

Three rules follow, and they are the ones worth holding onto:

**Read from `data/`, never from wherever the original lives.** An
analysis that reads the original works perfectly on your machine and
publishes a compendium with no data in it — and nothing would have told
you.

**Keep the originals, and never convert them in place.** Every
conversion costs something: an `.xlsx` loses its formulas, an `.sav` or
a `.dta` loses its value and variable labels — the values travel, the
codebook does not, and
[`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
says so when it happens. Two years from now, when a number in `data/`
looks wrong, the original is the only thing that answers. It is also why
[`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
only ever reads them.

**`data/` is not “my clean data”.** What it holds is a format
conversion, not a transformation. Filtering, recoding and excluding
individuals belong in the chunk that needs them, where a reviewer can
read the decision, never as a derived file nobody can trace.
`check_data()` reports what is sitting in there that the analysis never
reads — it travels to the repository all the same.

## Writing

The order of a first day, once the project exists:

1.  Open the `.Rproj`, then `source("make.R")`.
2.  Fill in the affiliations in `_sections/0_authors.qmd`. The names are
    already there if you passed `authors`, with their marks in place.
3.  Write. `_sections/2_introduction.qmd` is plain markdown: headings
    and paragraphs, nothing to declare.
4.  Bring your data in with
    `convert_data("path/to/your/original.xlsx")`. It lands in `data/`,
    converted or copied. Read from **there**, with the path relative to
    the project root: your originals never travel to the deposit, so an
    analysis that reads them where they live would publish a compendium
    with no data in it.
5.  `render_html()` whenever you want to look at it. Seconds, not
    minutes.

From there it is one loop — write, render, repeat — and the analysis
lives inside the section that reports it:

    ```{r}
    #| label: richness-model
    #| cache: true
    richness <- readr::read_csv(here::here("data/richness.csv")) |>
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
| `render_docx()` | the `.docx`, with the journal’s citation style and Word template | `output/` |
| `render_pdf()` | the `.pdf` for bioRxiv or EcoEvoRxiv | `output/` |
| `render_supplementary()` | the supplement on its own, with its own reference list | `output/` |
| `export_code()` | `analysis_code.R` and `sessionInfo.txt` | `output/` |
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
| `journal` | the manuscript’s own | Which `.csl` in `references_styles/` sets the citation style. Left out, it is the one `manuscript.qmd` declares in its `csl:` line; naming one here wins for that call. `list_journals()` lists the ones you have |
| `caption_style` | `"default"` | How a caption is written: `"default"` gives *Figure 1.*, `"abbrev"` gives *Fig. 1.*, `"nature"` gives *Figure 1* followed by a vertical rule, `"compact"` gives *F1:* |
| `suppl_figures` | `"separate"` | Whether the supplementary figures and tables travel with the supplement or stay at the end of the manuscript. Either way they are cited from the main text |

One thing worth reading once: **the manuscript and its supplement are
never joined into a single file**. Each render writes one document per
section, into `output/`, each with its own reference list. Joining them
would mean handing both to pandoc, which rebuilds a `.docx` rather than
copying it, and a rebuilt table loses the column widths it was given:
the headings reach Word broken across two lines. One document per
section is also the shape a journal asks for.

Two more exist for the supplement alone: `render_supplementary()` takes
`output_format` (`"docx"` by default) and `files`, a subset of the
supplementary documents — which is how `make_submission()` renders only
the supplementary *text* when the figures are staying in the main
document.

`run.R`, inside the project, lists every command with each argument
explained, ready to run one line at a time. It is the file to open when
you cannot remember a name.

## Adding a journal

The template ships nine styles, all from ecology. Any other journal’s is
one call away, and it goes where `render_docx()` looks:

``` r

easypaper::add_journal("plos-one")   # -> references_styles/plos-one.csl
render_docx("plos-one")
```

The name is the one the official CSL repository uses — the file name
without `.csl`, lower case, hyphens — and Zotero’s style finder at
<https://www.zotero.org/styles> searches it by journal; its URLs work
too. Most journals have a *dependent* style, a few lines pointing at the
parent whose rules they share. Pandoc cannot follow that pointer, so
what lands in the project are the parent’s rules under the name you
asked for, and the message says which parent it was.

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
| Writes into | `output/` | `submission/<label>/` |
| The manuscript | one file, complete | title page and main text, as two files |
| The title | on the front | on both: the title page and the head of the main text |
| The authors | on the front | only on the title page; the main text is built without them |
| The supplement | inside the document | its own file, cited as *Figure S1* from the main text |
| The figures | embedded in the document | also on their own, at 600 dpi and renumbered in order |
| Data and code | — | the compendium and its `.zip`, `renv.lock` included |
| Also writes | — | a cover letter and a `CHECKLIST.md` |
| `renv.lock` | rewritten, to describe this render | rewritten, and copied into the compendium |

``` r

make_submission("myrmecological-news")            # -> submission/MyrmecologicalNews/
make_submission("myrmecological-news", label = "Journal1")   # your own name for it
```

| Argument | Default | What it decides |
|----|----|----|
| `journal` | the manuscript’s own | The `.csl` the citations come out in, from `manuscript.qmd` unless you name one |
| `label` | the journal’s name | Names the folder inside `submission/` and every file in it. Left alone it is the journal’s own name with the spaces taken out, so `"ecology-letters"` lands in `submission/EcologyLetters/`. Pass your own for a second version, or for a trial you want to keep apart |
| `caption_style` | `"default"` | As in the renders above |
| `figure_format` | `"tiff"` | The standalone figures the journal uploads: `"tiff"`, `"png"` or `"jpg"`. TIFF unless they say otherwise — JPEG is lossy and poor for line art |
| `blinded` | `TRUE` | Splits title page from main text the way double-blind review asks: the main text opens with the title alone, the author block is dropped and `0_authors.qmd` is left out, so no name travels in it. `FALSE` when the journal wants them in |
| `snapshot` | `TRUE` | Runs `renv::snapshot()` first, so the `renv.lock` that travels in the compendium describes the environment *this* submission came out of. The renders record it too, but a submission is the one you will be asked about. `FALSE` if you keep the lockfile by hand |
| `suppl_figures` | `"separate"` | Whether the supplementary figures and tables go out on their own or at the end of the main text. Either way they are cited from the main text |

That builds, from what is already in the project:

    submission/MyrmecologicalNews/
      cover_letter_MyrmecologicalNews.docx               template, never overwritten
      CHECKLIST.md                            what still has to be done by hand
      manuscript/
        title_MyrmecologicalNews.docx                    title, authors, affiliations, counts
        main_MyrmecologicalNews.docx                     the title, then the Abstract on, no names
        supporting_information_*.docx
        figures/Figure_1.tiff ...             600 dpi, renumbered in order
      data_and_code/                          data, metadata, scripts, renv.lock
      data_and_code.zip                       for Zenodo or Dryad

The split into title page and main text is what double-blind review asks
for. The names cannot leak into the main text because it is not built
with them: the author block is dropped and the authors section is left
out. The title does travel, at the head of the document, because that is
what a journal expects to see on an anonymised manuscript. What is *not*
checked for you — acknowledgements, CRediT, and self-citations of the
kind “in our previous study (Author et al.)” — is listed in the
`CHECKLIST.md`.

The compendium publishes open formats only: what is in `data/`, never
the source `.xlsx`, and only the analysis code, not your authoring
tooling. Its `README.txt` is written from what the folder actually
holds, so it never needs editing.

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
check_data()        # files in data/ that the analysis never reads
```

The second one has caught more submissions than the rest together: a
figure defined and never cited is a figure the journal will ask you
about.

## Keeping a project up to date

The build logic lives in the project, which is what lets it render with
easypaper uninstalled — and what keeps a fix in the package from
reaching a project already written.
[`update_project()`](https://danielsangarci.github.io/easypaper/reference/update_project.md)
is the bridge:

``` r

easypaper::update_project(dry_run = TRUE)   # what would change
easypaper::update_project()                 # do it
```

It refreshes an explicit list — `make.R`, `run.R`, `R/submission.R`,
`R/crossref_styles.R`, `R/convert_data.R`, the Word templates and the
`.csl` files the template ships — and never touches `_sections/`, the
YAML, `_quarto.yml`, `references/`, `data/` or `R/setup.R`. Nothing is
deleted. It asks for a clean git working tree first, so the update is
one commit you can read with `git diff` and revert file by file. What a
version leaves to you — 0.2.0’s move from `data/csv/` to `data/`, say —
is printed, not done. The stamp at the top of `make.R` then records both
the version that created the project and the one it was updated to.

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
