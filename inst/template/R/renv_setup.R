# ---------------------------------------------------------------------------
# Dependency management with renv. Run ONCE when starting the paper.
#
# What goes into git: renv.lock  (the manifest)
# What does not:      renv/library/  (the packages; .gitignore excludes it)
#
# NOTE: renv does NOT capture external binaries. In this project the only one
# left is QUARTO, which ships its own pandoc inside (so there can no longer be
# a mismatch between RStudio's pandoc and Homebrew's) and which resolves
# cross-references natively, without pandoc-crossref.
# Record its version: make.R writes it into
# output/sessionInfo.txt, and `quarto check` verifies the whole
# installation.
# ---------------------------------------------------------------------------
library(renv)

## 1. Initialise (once, when creating the project from the template)
# renv::init()

## 2. After installing or updating packages, record the state
# renv::status()     # what changed
# renv::snapshot()   # writes renv.lock  <- THIS file goes into git

## 3. On another machine (co-author, reviewer, your new laptop):
# renv::restore()    # reinstalls the exact versions from the .lock

## DO NOT run renv::deactivate(clean = TRUE): it undoes all of the above and
## leaves the project without dependency control. It was in the previous
## version of this script and defeated its purpose.
