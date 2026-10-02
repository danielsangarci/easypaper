# easypaper <a href="https://danielsangarci.github.io/easypaper/"><img src="man/figures/logo.png" align="right" height="138" alt="easypaper website" /></a>

<!-- badges: start -->
[![Project Status: Active – The project has reached a stable, usable state and is being actively developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R CMD check](https://github.com/danielsangarci/easypaper/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/danielsangarci/easypaper/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/danielsangarci/easypaper/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/danielsangarci/easypaper/actions/workflows/pkgdown.yaml)
[![Website](https://img.shields.io/badge/website-easypaper-1a5632.svg)](https://danielsangarci.github.io/easypaper/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

**Focus on your research: easypaper handles the formatting and the submission.**

Write your paper in Quarto, one section per file, with the analysis inside
it. easypaper renders it for any journal, checks it before every render, and
builds the folder you send.

- 📄 **One source, every output.** The journal's `.docx`, a `.pdf` for the
  preprint server, a working `.html` and the supplement, each in the citation
  style of the journal you name.
- 🕶️ **Double-blind review, done for you.** A title page and an anonymous
  main text, figures at 600 dpi, a cover letter, and a copy of the data and
  code that names nobody, for the reviewers.
- 🌿 **Scientific names checked against GBIF.** In italics in the reference
  list, where citeproc leaves them in roman, and reviewed in the text:
  italics, first mention, authority.
- ✅ **Checks before every render.** Citations with no entry, figures nobody
  cites, data nobody reads, packages nobody installed, and the word counts a
  submission form asks for.
- 📦 **Data and code ready to deposit.** Open formats, metadata filled in from
  the manuscript, `renv.lock` included, and the DOI reserved on Zenodo before
  you publish.

## Quick start

```r
# install.packages("remotes")
remotes::install_github("danielsangarci/easypaper")

library(easypaper)
create_paper("my_paper", title = "My title",
             authors = c("Ana Garcia", "Luis Perez"))
```

Open the `.Rproj` it creates, write in `_sections/`, and:

```r
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

`render_*()` makes documents to read, as often as you like; `make_*()`
assembles what you send, a few times per paper.

To see a finished paper first, `create_example_paper("example_paper")` writes
the same project with a small study in it, ready to render.

**Next:** [Get started](https://danielsangarci.github.io/easypaper/articles/easypaper.html)
walks through a paper from the first line to the submission, and
`?easypaper` lists every function.

## Requirements

R >= 4.1 and Quarto, which ships with RStudio and Positron. The `.pdf` also
needs LaTeX: `tinytex::install_tinytex()` is enough.

## Citation

```r
citation("easypaper")
```

> Sanchez-Garcia, D. (2026). easypaper: Automate Reproducible Quarto
> Manuscripts from Draft to Submission. R package version 0.1.0.
> https://github.com/danielsangarci/easypaper

## Licence

MIT for the code. The projects it writes carry MIT for code and CC BY 4.0 for
data, the pairing most journals and data repositories expect.
