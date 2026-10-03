# A summary of the manuscript

What a journal asks for on its submission form: the characters of the
title and of the short title when there is one, with and without spaces;
the words of the abstract; the keywords; the words of the main text,
without and with its reference list; the references cited; and the
figures and tables of the paper and of its supplement. Every render and
every `make_*()` prints it when it is done, once; this prints it on its
own.

## Usage

``` r
manuscript_stats(quiet = FALSE, path = ".")
```

## Arguments

- quiet:

  `TRUE` returns the counts without printing them.

- path:

  The project, or any folder inside it. The working directory by
  default, which is the project root once its `.Rproj` is open.

## Value

A named integer vector, invisibly when printed: `title_chars`,
`title_chars_no_spaces`, `short_title_chars` and
`short_title_chars_no_spaces` (`NA` without one), `abstract_words`,
`keywords`, `main_words`, `main_words_with_refs`, `references`,
`figures`, `tables`, `suppl_figures` and `suppl_tables`.

## Details

Words are counted the way Word counts them in the rendered document, not
in the source: a citation counts as the text the journal's style prints
for it – `[@smith2020]` as "(Smith 2020)" – a cross-reference as "Figure
1", and code, comments and markup not at all. The abstract is the
`# Abstract` section without its keywords line; the main text is every
section from the one after the abstract to the reference list, less the
statements at the end – acknowledgements, funding, author contributions,
conflicts of interest, data availability, ethics – whatever they are
called: Introduction to Discussion, in the template. The reference list
is the one the paper prints, in the journal's style. The value of inline
R code is not known until it runs, and counts as one word.

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, title = "Ant colonies", git = FALSE)
#> Project created: /tmp/RtmppX1nkW/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
if (rmarkdown::pandoc_available()) manuscript_stats(path = dir)
#> Manuscript summary
#>   Title                   12 characters
#>   Title, without spaces   11 characters
#>   Abstract                14 words
#>   Keywords                 3
#>   Main text                0 words
#>   Main text + references  41 words
#>   References               1
#>   Figures                  2
#>   Tables                   2
#>   Supplementary figures    1
#>   Supplementary tables     1
unlink(dir, recursive = TRUE)
```
