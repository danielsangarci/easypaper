# Write the references of the R packages a manuscript uses

Writes a `.bib` entry for every package, as
[`knitr::write_bib()`](https://rdrr.io/pkg/knitr/man/write_bib.html)
does – keyed `R-<package>`, so the text cites `[@R-vegan]` – with the
names in their titles protected from the citation style. A journal style
that sets titles in sentence case would otherwise print *Vegan:
Community ecology package* and *easypaper: Automate reproducible quarto
manuscripts*: the name of the package capitalised as the first word, and
the names of other software lowercased. Three things are kept as
written, between braces, the way BibTeX protects a word:

## Usage

``` r
write_packages_bib(x = .packages(), file)
```

## Arguments

- x:

  The packages, by name.
  [`.packages()`](https://rdrr.io/r/base/zpackages.html), the default,
  are those attached in the session that calls it.

- file:

  The `.bib` file to write.

## Value

The path of `file`, invisibly.

## Details

- the name of the package at the head of its title – `{vegan}:`;

- the software its DESCRIPTION names in single quotes, as CRAN asks –
  `{Quarto}`, `{Excel}` – which knitr writes without the quotes;

- R, on its own.

The template calls it in the last chunk of `manuscript.qmd`, so the file
is written again on every render, with the packages of that render.

## Examples

``` r
f <- tempfile(fileext = ".bib")
write_packages_bib(c("base", "knitr"), f)
grep("title", readLines(f), value = TRUE)
#> [1] "  title = {{R}: A Language and Environment for Statistical Computing},"              
#> [2] "  title = {{knitr}: A General-Purpose Package for Dynamic Report Generation in {R}},"
#> [3] "  title = {Dynamic Documents with {R} and knitr},"                                   
#> [4] "  booktitle = {Implementing Reproducible Computational Research},"                   
#> [5] "  title = {{knitr}: A Comprehensive Tool for Reproducible Research in {R}},"         
unlink(f)
```
