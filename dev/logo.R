# ---------------------------------------------------------------------------
# The hexagon, drawn rather than stored: a paper plane over the manuscript it
# was folded from. Run this to regenerate man/figures/logo.png after changing
# a colour or a proportion.
#
#   Rscript dev/logo.R
#
# Standard sticker geometry (hexb.in): 2 in tall by 1.732 wide, points up and
# down. usethis::use_logo() scales the result to the 240 px the README uses.
# ---------------------------------------------------------------------------

green <- "#1a5632"   # the primary of _pkgdown.yml
edge  <- "#123C23"   # the border: the same green, darker
cream <- "#F4F1E8"   # the manuscript behind
paper <- "#FBF9F3"   # the lit side of the plane
fold  <- "#D3CCBA"   # the side in shadow
ochre <- "#C79A3F"   # section headings
ink   <- "#9FB6A8"   # body text

hex_xy <- function(r = 1) {
  a <- seq(90, by = -60, length.out = 6) * pi / 180
  list(x = r * cos(a), y = r * sin(a))
}
rot <- function(x, y, deg, cx = 0, cy = 0) {
  a <- deg * pi / 180
  list(x = cx + (x - cx) * cos(a) - (y - cy) * sin(a),
       y = cy + (x - cx) * sin(a) + (y - cy) * cos(a))
}

f <- tempfile(fileext = ".png")
png(f, width = 1.732, height = 2, units = "in", res = 600,
    bg = "transparent", type = "quartz")
par(mar = rep(0, 4), xaxs = "i", yaxs = "i")
plot.new(); plot.window(xlim = c(-0.866, 0.866), ylim = c(-1, 1), asp = 1)

# One border, not two: the whole hexagon in the dark tone, the field on top.
polygon(hex_xy(1), col = edge, border = NA)
polygon(hex_xy(0.962), col = green, border = NA)

# --- the manuscript, behind ------------------------------------------------
sx <- 0.245; sy0 <- -0.33; sy1 <- 0.35; tilt <- -11; cx <- -0.09; cy <- 0.26
sh <- rot(cx + c(-sx, sx, sx, -sx), cy + c(sy0, sy0, sy1, sy1), tilt, cx, cy)
polygon(sh$x, sh$y, col = cream, border = NA)

line <- function(y, w, col, lwd) {
  p <- rot(cx - sx + 0.05 + c(0, w), cy + c(y, y), tilt, cx, cy)
  segments(p$x[1], p$y[1], p$x[2], p$y[2], col = col, lwd = lwd, lend = 1)
}
line(0.275, 0.25, ink, 4.5)                      # title
for (top in c(0.175, 0.010, -0.155)) {           # three sections
  line(top,         0.13, ochre, 2.8)
  line(top - 0.050, 0.37, ink,   2.0)
  line(top - 0.096, 0.26, ink,   2.0)
}

# --- the paper plane, in front ---------------------------------------------
s <- 0.86; pcx <- 0.07; pcy <- 0.08
P <- function(x, y) rot(x, y, -15, pcx, pcy)
nose <- P(pcx, pcy + 0.54 * s); tail <- P(pcx, pcy - 0.26 * s)
wl <- P(pcx - 0.42 * s, pcy - 0.46 * s); wr <- P(pcx + 0.46 * s, pcy - 0.46 * s)
# One silhouette and then the shaded half: no seam where the halves meet.
polygon(c(nose$x, wl$x, tail$x, wr$x), c(nose$y, wl$y, tail$y, wr$y),
        col = paper, border = green, lwd = 2.4)
polygon(c(nose$x, wr$x, tail$x), c(nose$y, wr$y, tail$y), col = fold,
        border = NA)
segments(nose$x, nose$y, tail$x, tail$y, col = green, lwd = 3)

text(0, -0.55, "easypaper", col = cream, cex = 1.48, family = "Palatino")
dev.off()

usethis::use_logo(f)
