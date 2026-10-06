# The affiliations of the manuscript, under the authors

Writes the affiliations and the correspondence line of the title block,
numbered from the `affiliations:` of each author in the YAML of
`manuscript.qmd`. The template calls it in a chunk right under the YAML,
and every render fills it in; you write the authors and never a number:

## Usage

``` r
affiliations(path = ".")
```

## Arguments

- path:

  The project, or any folder inside it. While a document is being
  rendered, the project of that document.

## Value

The affiliations as markdown: for the chunk to print while a render of
the package runs, and nothing in any other render; printed and returned
invisibly when called from the console.

## Details

    author:
      - name: Ada Lovelace
        affiliations: [ecology]
        email: ada@example.org
        corresponding: true
      - name: Alan Turing
        affiliations: [ecology, institute]
    affiliations:
      - id: ecology
        address: University X, Department of Ecology, City, Country
      - id: institute
        address: Institute Y, City, Country

comes out as `Ada Lovelace^1,*^, Alan Turing^1,2^` on one line, with
`^1^ University X, ...`, `^2^ Institute Y, ...` and
`^*^ Correspondence: ada@example.org` under it – the markdown of the
superscripts. The affiliations are numbered in the order the authors
name them. Each affiliation is one line, `address:`, written as the
paper prints it. It may also be written in place, quoted, as
`affiliations: ["University X, City"]`, or with Quarto's own fields
(`department:`, `name:`, `city:`, `country:` ...), joined department
first, then the name, the address, the city and the country.

In a `.docx` they have a paragraph style of their own, *Affiliation*:
the body text of the Word template without its first-line indent, which
you can restyle in Word for every affiliation at once.

A double-blind main text leaves the chunk out, and the title page of
[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
is given it.

Quarto's own preview,
[`preview()`](https://danielsangarci.github.io/easypaper/reference/render.md)
or `quarto preview`, gets nothing from it: there Quarto draws the title
block itself.

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, authors = c("Ada Lovelace", "Alan Turing"), git = FALSE)
#> Project created: /tmp/RtmpyulCis/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
affiliations(dir)
#> ^1^ Institution 1, Department, City, Country
#> ^2^ Institution 2, Department, City, Country
#> ^\*^ Correspondence: correspondent@example.org
unlink(dir, recursive = TRUE)
```
