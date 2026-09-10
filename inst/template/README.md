# Reproducible scientific paper template (Quarto)

The reference for this project: where each thing goes, how the numbering
works, what the traps are, and what to check before you send anything. It
travels inside the project, so it is still here when easypaper is not.

**Start here.** Open the `.Rproj`, then:

```r
source("make.R")     # loads every command
render_html()        # see what you have, in seconds
```

`run.R` lists every command with its arguments explained, ready to run one
line at a time — it is the file to open when you cannot remember a name. The
same arguments, in tables and with their defaults, are in the *Get started*
guide: <https://danielsangarci.github.io/easypaper/articles/easypaper.html>. You write in `_sections/`; everything else is either
configuration or generated.

The history of the template, for the curious, is at the end in
[From Rmarkdown to Quarto](#from-rmarkdown-to-quarto).

## Requirements

Quarto is **not** an R package: it is a separate binary that ships its own
pandoc inside.

```bash
brew install --cask quarto && quarto check
```

In R: `install.packages(c("quarto", "here", "knitr", "flextable", "ragg", "magick", "zip", "renv"))`.
And only if you are going to sync with Google Docs, `trackdown` **from
GitHub**: the CRAN version (1.1.1) does not accept `.qmd`, and neither does the
latest tagged release (v1.3.0) — Quarto support landed in 1.4.0, which was
never tagged. `remotes::install_github("ClaudioZandonella/trackdown")` installs
the `main` branch (1.5.1), which does have it.
The PDF needs LaTeX (`quarto install tinytex`).

## Building

Everything goes through `make.R`. You can call `quarto render` directly, but
then you skip the citation checks and the licence synchronisation.

```r
source("make.R")

render_docx("myrmecological-news")   # -> output/manuscript_myrmecological-news.docx
render_pdf()                 # -> output/preprint.pdf
render_supplementary()       # -> output/supporting_information.docx
render_html()                # -> output/manuscript.html  (fast, to check as you go)
export_code()                # -> output/analysis_code.R
make_all()                   # the four above -- not the .html

make_submission("myrmecological-news")       # submission folder, for a journal
make_preprint()                              # deposit folder, for a preprint

preview()                    # live preview while you write
list_journals()              # available CSL files
clean_cache()                # after changing data/
check_citations()            # cited keys missing from the .bib
```

### The verbs

Five prefixes, and each one is a promise:

- **`render_*`** -- one call to Quarto, one document to read, written into
  `output/`. The four of them are the same internal function with the format
  changed.
- **`make_*`** -- a deliverable assembled from several steps: a batch, or a
  folder. They are the targets of `make.R`, which is a Makefile written in R.
  None of them renders on its own; they chain the ones above.
- **`export_*`** -- derive a file from what already exists, without going
  through Quarto: the analysis code, the figure formats.
- **`check_*`** -- look and report. **Never writes.** This is the promise that
  matters most: it is why recording the environment lives in `.record_env()`
  and not in `check_renv()`, which only ever warns.
- everything else is a utility: `sync_licenses()`, `clean_cache()`,
  `list_journals()`, `preview()`.

The short form, worth keeping when you add the sixth function:
**`render_` makes a document, `make_` makes a deliverable, `check_` makes
nothing.**

Switching journal is an argument; no `.qmd` is touched:

```r
render_docx("ecology-letters", caption_style = "abbrev")
```

| `caption_style` | Result             |
|-----------------|--------------------|
| `default`       | `Figure 1. text`   |
| `abbrev`        | `Fig. 1. text`     |
| `nature`        | `Figure 1 \| text` |
| `compact`       | `F1: text`         |

New styles are added to `caption_styles` in `R/crossref_styles.R`.

## Structure

```
_quarto.yml            Project configuration: formats, paths, crossref
manuscript.qmd         Master: authors + skeleton of sections
make.R                 The only entry point
run.R                  Cheat sheet: every command ready to run, one line
                       at a time. Not called by anything
title_page.qmd         Separate title page (title, authors, counts)
supplementary.qmd      Supplementary material as a standalone file
submission/            Per-journal submission folders (generated)
_sections/             The text. This is where you write. The prefix is the
                       section of the paper (4.1 and 4.2 = the two parts of
                       Results); the build order comes from manuscript.qmd.
  1_abstract.qmd  2_introduction.qmd  3_methods.qmd
  4.1_results1.qmd  4.2_results2.qmd  5_discussion.qmd
  6_figures.qmd  7_tables.qmd  8_suppl_material.qmd
R/
  setup.R              Seed, palette, table and figure helpers
  submission.R         Builds the submission folder
  crossref_styles.R    Caption style per journal
  renv_setup.R         Dependencies
  convert_data.R       brings an original into data/ (converts or copies)
  create_metadata.R    dataspice metadata
  trackdown.R          Google Docs sync for co-authors
data/                  The data, in open formats. THIS is what gets published
                       and what the metadata describes. convert_data() brings
                       originals in; the originals themselves live wherever
                       you keep them, outside the project or in it
  metadata/            dataspice. `sync_metadata()` fills in what the project
                       already knows -- title, keywords, authors, the variable
                       names of data/ -- on every render, and only ever adds:
                       your descriptions and units are never rewritten
format/                Word templates: the manuscript (line-numbered, ragged
                       right), the supplement and the cover letter (both
                       justified, neither numbered)
references/            .bib
references_styles/     .csl per journal
output/                Everything a render produces, flat. Regenerable, in .gitignore.
figures/               png/ jpg/ tiff/, one copy per format. Regenerable.
cache/                 Written by knitr. Regenerable, in .gitignore.
```

Quarto ignores folders starting with `_` when looking for documents to render:
that is why `_sections/` does not produce nine standalone files.

## The path rule

One single rule: **everything is relative to the project root**, in the YAML
and in the R code. `_quarto.yml` sets `execute-dir: project`, so chunks run
with the working directory at the root, and the paths in `_quarto.yml`
(`reference-doc`, `csl`, `bibliography`, filters) are resolved by Quarto from
the root as well.

The double rule of the Rmarkdown version (`../format/...` in the YAML but
`here()` in the code) is gone — it was the classic reason a project "only
compiles on my machine". `here::here()` still works and is still used in the
`R/` scripts: Quarto's `_quarto.yml` is recognised by `here` as a project root,
so you do not even need the `.Rproj`.

## Working idiom

A typical analysis in a results section:

    ```{r}
    #| label: richness-model
    #| cache: true
    richness <- readr::read_csv(here::here("data/richness.csv")) |>
      dplyr::filter(!is.na(S), status != "dead") |>
      dplyr::mutate(treatment = factor(treatment, levels = c("control", "warmed")))

    m1 <- glmmTMB::glmmTMB(S ~ treatment + (1 | plot),
                           family = nbinom2, data = richness)
    ```

    Richness was higher in the treatment
    (beta = `r round(fixef(m1)$cond[2], 2)`), as shown in @fig-richness,
    in line with previous studies [@Akino1999].

- Cleaning happens **here**, from the input `.csv`, never as a derived file
  saved in `data/`. Excluding individuals or recoding a factor is a scientific
  decision: it has to be readable as code, not hidden in a `.csv` nobody can
  trace back. `#| cache: true` covers the cost of recomputing it.
- Chunk options go on `#|` lines inside the chunk, not in the header. Quarto
  **validates** them: a misspelled option is an error instead of being silently
  ignored.
- `#| cache: true` on the slow chunks; the dependent ones with
  `#| dependson: richness-model`.
- Figures are cited with `@fig-name` and tables with `@tbl-name`. Quarto adds
  the number and the link. The chunk label **must** start with `fig-` or
  `tbl-`, and the legend goes in `#| fig-cap` / `#| tbl-cap`.
- Supplementary material is numbered independently (`@sfig-`, `@stbl-`),
  defined under `crossref: custom:` in `_quarto.yml`.
- If you cite `@fig-whatever` and that figure does not exist, `make.R` catches
  it **before** rendering (`check_crossrefs()`), and it also warns about
  figures that are defined but never cited. It is deliberately not a Lua
  filter: Quarto resolves references *after* user filters, so a filter cannot
  tell a broken one from a good one.
- If you cite `[@key]` and it is not in `references/*.bib`, `make.R` catches it
  **before** rendering (`check_citations()`).
- Page break: `{{< pagebreak >}}`, which works in Word and in PDF. The LaTeX
  `\newpage` only worked in the PDF and Word dropped it silently.

### Numbering: the one change of habit

The previous system (`R/captions.R`) numbered by order of **first citation**.
Quarto numbers by order of **appearance** of the figure in the document. Since
all figures sit together at the end, in `_sections/6_figures.qmd`, all you have
to do is keep that section in the same order in which you cite them — which is
exactly what journals ask for. If the numbers look wrong, it is the text citing
out of order.

## Known traps

- **knitr runs chunks and inline code inside HTML comments** (`<!-- -->`).
  Verified. To disable a chunk use `#| eval: false`, never comment it out.
- **Google Drive corrupts git repositories** by syncing `.git/` file by file.
  Keep projects outside the Drive folder and sync through GitHub. For
  co-authors there is `trackdown`, which uploads plain text only.
- **`renv.lock` is written at submission time, not on render.**
  Every render that produces a document -- `render_docx()`,
  `render_pdf()`, `render_supplementary()`, and therefore `make_all()` --
  records `renv.lock` when it finishes, and so does `make_submission()` (turn
  it off there with `snapshot = FALSE`). `render_html()` does not: it is the
  loop you run while writing, and it is what you render after restoring an old
  environment to look into something, so it must never overwrite your record.
  You do not need `renv::init()` for any of this -- snapshot reads the project
  code and records
  what your own library holds. It records the dependencies of the *analysis*
  only: the manuscript, its sections and the scripts that go into the
  compendium. `trackdown`, `dataspice` and `EML` are your tooling and stay out,
  which took the lockfile of this template from 112 packages to 60.
- **The knitr cache does not notice changes in data files.** After touching
  `data/`, run `clean_cache()` (it also clears `_freeze/` and `.quarto/`).
- **`~/.Rprofile` is loaded in every R session.** If you define functions there
  and the manuscript uses them without you noticing, it will not reproduce on
  another machine. When in doubt:
  `R --vanilla -e 'source("make.R"); make_all()'`.
- **`renv` does not capture Quarto.** It is an external binary, as pandoc used
  to be. `make.R` records its version in
  `output/sessionInfo.txt`; put it in the *Data Availability
  Statement* too.
- **The pandoc mismatch is gone.** Quarto ships its own, so the "RStudio 3.8.3
  vs Homebrew 3.7.0.2" trap disappears. `pandoc-crossref` is not needed either:
  cross-references are native, numbered equations included
  (`$$...$$ {#eq-model}`).
- **Table captions are written by Quarto** (`#| tbl-cap`). Do not also use
  `flextable::set_caption()` or they will be duplicated.
- **The first PDF render installs LaTeX packages** (`caption.sty` and friends)
  through `tlmgr`, and the first time it may fail while `tlmgr` updates itself.
  Run it again and it goes through. It needs an internet connection.

### Authors and affiliations

This is the one place where Quarto is worse than the previous template, and it
is worth knowing why. Quarto **rebuilds the author line** of the title block
from its own schema, so:

- The Lua filters of the previous template (`scholarly-metadata.lua` +
  `author-info-blocks.lua`) lose the superscripts and the correspondence line
  there. With plain pandoc they work; under Quarto they do not. Verified with
  Quarto 1.9.38, and that is why they are no longer in `format/`.
- Quarto's native schema (`author:` with `affiliations:`, `orcid:`,
  `corresponding:`) does work in PDF and HTML, but in `.docx` it **only prints
  the names**: no affiliations, no asterisk.

This template's solution is to write it explicitly in `manuscript.qmd`: the
mark goes inside the name and the affiliations are the first three lines of the
body.

```yaml
author:
  - name: "Ana Garcia^1,\\*^"
  - name: "Luis Perez^2^"
```

```markdown
^1^ University X, Department of Ecology, City, Country

^2^ Institute Y, City, Country

^\*^ Correspondence: ana.garcia@example.org
```

It comes out identical in `.docx`, `.pdf` and `.html` (verified), and `make.R`
still reads the copyright holders from there: `.author_names()` strips the
marks before writing them.

## Figures

knitr writes the PNGs at 600 dpi into `figures/png/`, and at the end of every
render `export_figure_formats()` produces the copies in `figures/jpg/` and
`figures/tiff/`:

```
figures/
  png/   fig-richness-1.png      <- what knitr produces and the document embeds
  jpg/   fig-richness-1.jpg      <- quality 95
  tiff/  fig-richness-1.tiff     <- LZW compression
```

Converting instead of rendering three times, for two reasons: changing knitr's
device would force a re-run of the whole analysis, and this way the three
copies are certainly the *same* figure.

All three carry an explicit 600 dpi in their metadata. That is deliberate: the
`ragg` PNG stores the density in pixels per centimetre (236 px/cm, which is
exactly 600 dpi) and some journals have automated checks that compare the
number against 600 without looking at the unit.

**About JPEG:** it is lossy and a poor choice for line art or figures with text
— it leaves artefacts around the strokes. It is here because some journals
require it. If you get to choose, send the TIFF.

`make_submission(figure_format = "tiff")` takes them from whichever subfolder
you name and renumbers them to `Figure_1`, `Figure_2`… in order of appearance.

## Supplementary material

Two kinds of supplementary content, told apart by what the file contains --
nothing to declare anywhere:

- **Figures and tables**: any `_sections/8*suppl*.qmd` that defines an `sfig`
  or `stbl` div. Cited from the main text as `@sfig-map`, `@stbl-raw`.
- **Text**: an extended Methods, a longer rationale. Any supplementary file
  with no floats in it. It always leaves as its own document, which is the
  point: its reference list is independent from the main text's.

Name them after the section they belong to, as Results is already 4.1 and 4.2:
`_sections/8.1_suppl_figures.qmd`, `_sections/8.2_suppl_methods.qmd`. Then
point `manuscript.qmd` (under `# Supporting information`) and
`supplementary.qmd` at them.

### Where the figures and tables go

`make_submission(suppl_figures = )` decides, and the citations in the main text
work either way:

| | `"separate"` (default) | `"main"` |
|---|---|---|
| Figures and tables | own document | at the end of `main_*.docx` |
| `@sfig-map` in the main text | rewritten to the text `Figure S1` | resolved by Quarto natively |
| Supplementary text | own document | own document |

```r
make_submission("myrmecological-news")                          # separate
make_submission("myrmecological-news", suppl_figures = "main")   # at the end of the main text
```

Outputs: with one supplementary document it is
`supporting_information_<Journal>.docx`; with several, each is named after its
file -- `supporting_information_figures_<Journal>.docx`,
`supporting_information_methods_<Journal>.docx`.

### Numbering

With every supplementary figure in a single file, numbering is flat: `Figure
S1`, `Figure S2`, `Table S1`. It only changes if you spread the figures over
**several** documents, and then it has to: Quarto restarts its counter in each
document it renders, so two files would both open at `Figure S1`, naming two
different figures. In that case the prefix carries the appendix -- `Figure
S1.1`, `Figure S2.1` -- which is what journals ask for. The main text follows
suit.

## Independent bibliographies

The supplementary material has its own bibliography, separate from the one in
the main text. Verified with a citation that appears only in the supplement:

| Document | Bibliography |
|---|---|
| `supporting_information.docx` (standalone) | only the supplement's citations |
| `main_*.docx` from the submission | only the main text's |
| the complete `manuscript.qmd` | both, in a single list |

Both are independent renders, and that is what goes to the journal. There is
no third option that puts them in one file: producing it means handing both
documents to pandoc, which rebuilds them instead of copying, and the rebuilt
tables reach Word with their column widths gone and every heading broken over
two lines. One document per section, always.

Because the supplement leaves the main text, the citations to it (`@sfig-map`)
are replaced by their own text (`Figure S1`): their target is no longer in the
document.

## Submission folder

`make_submission()` builds, out of what is already in the project, the folder
you send to the journal and upload to the data repository. For a preprint the
sibling is `make_preprint()`, further down: same machinery, one signed `.pdf`
instead of a blinded pair of Word files.

```r
make_submission("myrmecological-news")                             # -> submission/default/
make_submission("myrmecological-news", label = "MyrmecologicalNews")   # the real one
```

`label` names the folder and every file inside it. It defaults to `"default"`,
so a trial run lands in `submission/default/` and is unmistakably a trial:
without an explicit label nothing ever carries the name of a journal you did
not choose. Pass the real name when you actually submit.

```
submission/default/
  cover_letter_default.docx                 template; NOT overwritten if it exists
  CHECKLIST.md                              what has to be done by hand
  manuscript/
    title_default.docx                      from the title to just before the Abstract
    main_default.docx                       the title, then the Abstract on, no authors
    supporting_information_default.docx
    figures/Figure_1.tiff  Figure_2.tiff    600 dpi, LZW, in order
  data_and_code/
    data/                                   open formats only; no .xlsx
    metadata/                               dataspice
    scripts/                                setup.R, analysis_code.R, sessionInfo.txt
    README.txt                              written from the folder contents
    LICENSE  LICENSE-CODE  renv.lock  .Rproj
  data_and_code.zip                         the same, for Zenodo/Dryad
```

**The compendium publishes only open formats and only analysis code.** It
carries `data/` whole; your original `.xlsx` and `.sav` are not in there, and
a closed format that finds its way into `data/` is dropped on the way out. What
was already an open format -- a GeoPackage, a NetCDF -- travels untouched. And of the
scripts, only `setup.R` and the analysis go in -- `convert_data.R`,
`create_metadata.R`, `renv_setup.R`, `trackdown.R`, `submission.R` and
`crossref_styles.R` are your tooling, not the paper's method. It is a
whitelist: name an extra analysis script `R/analysis_*.R` and it is included
automatically; anything else you drop in `R/` stays out.

Five decisions worth knowing about:

**The manuscript is split into title page and main text**, which is how
journals with double-blind review ask for it. The title page carries title,
authors, affiliations, correspondence and the counts; the main text opens with
the title, goes on to the Abstract, and contains not one name or affiliation
(verified). The title is on both on purpose: a journal expects it at the head
of the anonymised manuscript, and it identifies nobody. With
`blinded = FALSE` the main text keeps the whole title block, authors included.

The cut does not touch the code: the `setup` chunk is still there, only what
gets printed disappears. What is **not** touched, and you have to review
yourself, are the *Acknowledgements* and *CRediT* sections at the end and
self-citations of the kind "in our previous study (Author et al.)": they
identify you too. It is in the `CHECKLIST.md`.

**The main text comes out without the supplementary material**, which is what
almost every journal wants, and the citations to its figures are replaced by
their text: `@sfig-map` becomes `Figure S1`. This is done in R on the source
rather than with a Lua filter because Quarto resolves cross-references *after*
user filters: once the target is cut, the citation would be left as
`?@sfig-map` inside the `.docx` that goes to the editor. Verified. The
numbering is computed with the same rule Quarto uses (order of appearance) and
the same prefixes, so it matches the standalone supplementary file.

**Figures come out renumbered** `Figure_1`, `Figure_2`… in the order they
appear in `_sections/6_figures.qmd`, in TIFF with LZW compression and an
explicit 600 dpi density (the PNG stores 236 px/cm and some journals check
">= 600 dpi" literally). With `figure_format = "png"` they are copied as they
are.

**The compendium does not carry the build tooling** (`submission.R`,
`trackdown.R`, `crossref_styles.R`): whoever reviews it wants the analysis, not
the publishing system.

Everything is regenerable: you can run it as many times as you like. The only
exception is the cover letter, which is never overwritten once written.

What is still yours is in `CHECKLIST.md`: cover letter, word counts, ORCID,
suggested reviewers, graphical abstract, and the repository DOI for the *Data
availability statement*.

## From Rmarkdown to Quarto

Direct equivalences:

| Rmarkdown + bookdown | Quarto |
|---|---|
| `output: bookdown::word_document2` in the YAML | `format: docx` in `_quarto.yml` |
| `reference_docx:` | `reference-doc:` |
| `knit_root_dir = here()` in `render()` | `execute-dir: project` |
| ```` ```{r child=...} ```` | `{{< include _sections/... >}}` |
| `knitr::opts_chunk$set()` in a chunk | `execute:` and `knitr: opts_chunk:` in the YAML |
| `{r name, echo=FALSE}` | `#| label:` / `#| echo: false` inside the chunk |
| `R/captions.R`, `captioner` | native `@fig-x`, `@tbl-x` |
| `check_captions()` | `check_crossrefs()` in `make.R` |
| `\newpage` | `{{< pagebreak >}}` |
| author Lua filters | title block written by hand (see above) |
| `rmarkdown::render(...)` | `quarto::quarto_render(...)` |

**What you gain**

1. **Configuration leaves the manuscript.** Formats, paths, bibliography and
   numbering style live in `_quarto.yml`, with paths relative to the root. The
   `.qmd` only holds content. The double path rule is gone.
2. **Native cross-references.** Figures, tables, equations, sections and custom
   types (the supplement), numbered and **linked** in Word, PDF and HTML. That
   removes 90 lines of `R/captions.R` and the dependency on `captioner`
   (archived on CRAN). `bookdown` is no longer needed for this.
3. **One source, several outputs for real.** `--to docx|pdf|html|typst` without
   touching the document. Before, each output was a different YAML block.
4. **`quarto preview`.** Live reload while you write, instead of waiting for a
   whole `.docx`.
5. **Validated chunk options.** `#| eco: false` is an error; `eco=FALSE` in
   Rmarkdown was silently ignored (that is how the `dev="ragg_png"` that never
   applied and the non-existent `"The New Roman"` font slipped through).
6. **Pandoc ships inside.** End of the RStudio/Homebrew mismatch, and of giving
   up `pandoc-crossref` because its version could not be pinned.
7. **Hyperlinked references** in Word too: `@fig-x` and `@tbl-x` produce
   internal links, and the supplement numbers separately (`Figure S1`) with
   nothing to configure.
8. **Journal templates as extensions.** `quarto use template
   quarto-journals/elsevier` (also PLOS, ACM, JSS...) sets up the journal
   format without fighting a `.docx`.
9. **`project: type: manuscript`.** If one day you want to publish the paper as
   a website with the notebooks alongside and a MECA package to submit, it is
   built for that.
10. **It does not depend on RStudio.** RStudio, VS Code, Positron, Neovim or the
    terminal, with the same visual editor. And it takes Python or Julia chunks
    in the same document if some analysis needs them.
11. **`quarto check`** verifies R, knitr, pandoc and LaTeX in one go.
12. **It is what is being developed.** rmarkdown and bookdown are in
    maintenance; Posit's new work goes into Quarto.

**What it costs**

- One more external binary to install, and one `renv` does not capture (as with
  pandoc before, but now it is explicit).
- **The title block has to be written by hand** (see above). It is the only
  thing lost relative to the Rmarkdown template.
- Numbering becomes order of appearance, not order of first citation (see
  above).
- New syntax to learn: `#|`, `{{< >}}`, `@fig-`.
- `bookdown` had things that are not used here (`\@ref()`, books with
  chapters). If one day you write a thesis by chapters, the equivalent is a
  Quarto project of type `book`.

## Licences

A *research compendium* mixes code and scientific content, which are not
licensed the same way:

| Content | Licence | File |
|---|---|---|
| **Code** — `make.R`, `R/*.R`, chunks in `_sections/*.qmd` | [MIT](https://opensource.org/licenses/MIT) | [`LICENSE-CODE`](LICENSE-CODE) |
| **Text, figures, tables and data** — `_sections/`, `figures/`, `data/` | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | [`LICENSE`](LICENSE) |

### Licence notice for the content

<!-- license:start | generated by sync_licenses() from the YAML of manuscript.qmd -- do not edit by hand -->
> (c) 2026 Author1 & Author2. The text, figures, tables and data of this compendium
> are licensed under
> [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).
<!-- license:end -->

This is the right place for that notice, not inside `LICENSE`. Creative Commons
explicitly asks that **the text of its licences not be modified**: CC BY is
applied by *marking the work*, not by editing the terms. In fact the official
CC BY 4.0 carries no copyright line at all, and the `LICENSE` file in this
repository is the official text byte for byte.

`LICENSE-CODE` is the opposite case: the `Copyright (c) YEAR HOLDER` line **is**
part of the MIT terms, which require including "the above copyright notice" in
every copy. Without a name, that clause points at nobody.

**Nothing has to be filled in by hand.** `sync_licenses()` reads the authors
from the YAML of `manuscript.qmd` and writes the holders into `LICENSE-CODE`
and into the notice above. It runs on its own in every `render_docx()` /
`render_pdf()`, so the YAML is the single source of truth: change a
co-author there and the licences update in the next build.

Neither file has a `.md` extension, for two reasons. GitHub detects the licence
by comparing the file against a list of known licences (the `licensee` gem, at
a high confidence threshold), and any added text breaks that detection; Zenodo
imports that metadata from GitHub when minting the DOI. And with `.md` GitHub
renders the legal text as Markdown: it loses the indentation and swallows
whatever sits between `<` and `>` as HTML.

**Why CC BY and not CC0 for the data.** CC0 (public domain) is the other common
option and is **mandatory on Dryad**: their terms say that by submitting you
grant irrevocable permission to publish the dataset under CC0, whatever your
files say. But on Zenodo, Figshare or GitHub you can choose, and CC BY is better
for you: it turns attribution into a **legal** obligation, not just a
disciplinary norm.

This matters especially in the EU. In the US raw data are barely protectable
(*Feist v. Rural Telephone*), but in Europe there is the ***sui generis*
database right** (Directive 96/9/EC; in Spain, arts. 133-137 LPI), which
protects the substantial investment in obtaining and verifying a database
independently of copyright. Section 4 of CC BY 4.0 covers it expressly, so the
licence is effective here.

**If a journal forces you to deposit in Dryad:** change nothing. Submit anyway
and it will sit under CC0 there; you are still the holder and you can licence
the same material under CC BY in your compendium. Mention it in the *Data
Availability Statement* so it does not look contradictory.

**If the journal forces you to assign copyright of the text** (common in
subscription journals), CC BY still applies to the *preprint* and to the
compendium, not to the publisher's typeset version. Each journal's specific
policy is at [SHERPA/RoMEO](https://v2.sherpa.ac.uk/romeo/).

## Preprint deposit

```r
make_preprint()                       # -> submission/bioRxiv/
make_preprint(label = "EcoEvoRxiv")   # another server
make_preprint(label = "bioRxiv_v2")   # the revised version
```

The other destination, built with the same parts:

```
submission/bioRxiv/
  README.md                       what goes to the server, what to the repository
  manuscript/
    preprint_bioRxiv.pdf          the manuscript, signed
    supporting_information_bioRxiv.pdf
    figures/Figure_1.tiff ...
  data_and_code/                  as above
  data_and_code.zip
```

Two differences from a submission, and both are deliberate. The manuscript is
**one signed PDF**: a preprint is not reviewed blind, and hiding the authors
would defeat the reason for posting it. And there is no cover letter, because
there is no editor.

The order matters more than it looks: **deposit the data and code first**. You
need the DOI of that deposit to cite it in the manuscript, and a preprint
edited after posting becomes a new version rather than a correction. The
`README.md` inside the folder carries that reminder and the rest of what is
left to you.

## Before submitting

- [ ] `set.seed()` fixed in `R/setup.R` if there is randomness (permutations,
      bootstrap, rarefaction, MCMC).
- [ ] `renv::snapshot()` run and `renv.lock` committed.
- [ ] Quarto version recorded (`quarto --version`); it appears on its own in
      `output/sessionInfo.txt`.
- [ ] `make_all()` from scratch (`clean_cache()` first) with no errors.
- [ ] `git tag submission-1`
- [ ] Data metadata: `source("R/create_metadata.R")`
- [ ] Put the real authors in the YAML of `manuscript.qmd`. The copyright
      holders of `LICENSE-CODE` and of the notice in this README come from
      there on their own (`make_all()` warns if the YAML still has the template
      authors). `LICENSE` is never touched: it is the official CC BY text.
