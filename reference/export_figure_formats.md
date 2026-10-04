# Copy every figure to JPEG and TIFF at 600 dpi

knitr writes one format per render, PNG, into `figures/png/`. This
converts each of them into `figures/jpg/` and `figures/tiff/`, at 600
dpi and with the TIFF compressed losslessly (LZW), which is what
journals ask for on acceptance. Converting is faster than rendering
three times, and guarantees the three copies are the same figure. Every
render does it on its own.

## Usage

``` r
export_figure_formats(quiet = FALSE, path = ".")
```

## Arguments

- quiet:

  `TRUE` says nothing.

- path:

  The project, or any folder inside it. The working directory by
  default, which is the project root once its `.Rproj` is open.

## Value

The PNG files converted, invisibly.

## Details

JPEG is lossy and a poor choice for line art or figures with text. It is
here because some journals require it; if you get to choose, send the
TIFF.

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, git = FALSE)
#> Project created: /tmp/RtmpRj0IWO/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
dir.create(file.path(dir, "figures", "png"), recursive = TRUE)
grDevices::png(file.path(dir, "figures", "png", "fig-a-1.png"))
plot(1:10)
invisible(grDevices::dev.off())
export_figure_formats(path = dir)
#> Figures: 1 x png/jpg/tiff in figures/
list.files(file.path(dir, "figures"), recursive = TRUE)
#> [1] "jpg/fig-a-1.jpg"   "png/fig-a-1.png"   "tiff/fig-a-1.tiff"
unlink(dir, recursive = TRUE)
```
