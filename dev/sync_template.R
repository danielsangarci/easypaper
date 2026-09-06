# ---------------------------------------------------------------------------
# Refresh inst/template/ from a working manuscript project.
#
# The template is a copy of a real project, and copying it by hand is where
# this package will break: a forgotten rename, a generated folder that travels,
# a .gitignore that R CMD build then drops. This script does the whole thing,
# and tests/testthat/test-template.R checks the result.
#
#   Rscript dev/sync_template.R "~/Mi unidad/Investigacion/RTools/quarto_project_structure"
#
# Afterwards: devtools::test() and devtools::check().
# ---------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
src  <- if (length(args)) path.expand(args[1]) else
  stop("Give the path of the project to copy from.", call. = FALSE)
if (!file.exists(file.path(src, "_quarto.yml"))) {
  stop("`", src, "` does not look like a manuscript project (no _quarto.yml).",
       call. = FALSE)
}

dest <- file.path(getwd(), "inst", "template")
if (!dir.exists(dirname(dest))) {
  stop("Run this from the root of the package.", call. = FALSE)
}

# Regenerable, private, or dead: none of it belongs in a scaffold.
skip_dirs  <- c("output", "figures", "cache", "submission", "_legacy_rmd",
                ".quarto", ".Rproj.user", "renv")
skip_files <- c("renv.lock", ".DS_Store", ".Rhistory", ".Rapp.history",
                ".RData")

unlink(dest, recursive = TRUE)
dir.create(dest, recursive = TRUE)

copy_into <- function(from, to) {
  for (f in list.files(from, all.files = TRUE, no.. = TRUE)) {
    p <- file.path(from, f)
    if (dir.exists(p)) {
      if (f %in% skip_dirs) next
      dir.create(file.path(to, f), showWarnings = FALSE)
      copy_into(p, file.path(to, f))
    } else {
      if (f %in% skip_files || grepl("^tmp_", f)) next
      file.copy(p, file.path(to, f), overwrite = TRUE)
    }
  }
}
copy_into(src, dest)

# R CMD build drops dotfiles from inst/, and the .Rproj is renamed per project.
if (file.exists(file.path(dest, ".gitignore"))) {
  file.rename(file.path(dest, ".gitignore"), file.path(dest, "gitignore"))
}
rp <- list.files(dest, pattern = "[.]Rproj$", full.names = TRUE)
if (length(rp)) file.rename(rp[1], file.path(dest, "Rproj.template"))

# Empty folders are created by create_paper(), not carried as .gitkeep.
unlink(list.files(dest, "^[.]gitkeep$", recursive = TRUE, all.files = TRUE,
                  full.names = TRUE))

n <- length(list.files(dest, recursive = TRUE, all.files = TRUE))
message("Template refreshed from ", src, ": ", n, " files.\n",
        "Now run devtools::test() and devtools::check().")
