# ---------------------------------------------------------------------------
# The references of the R packages a manuscript uses, with their names kept
# as they are written.
# ---------------------------------------------------------------------------

#' Write the references of the R packages a manuscript uses
#'
#' Writes a `.bib` entry for every package, as [knitr::write_bib()] does --
#' keyed `R-<package>`, so the text cites `[@R-vegan]` -- with the names in
#' their titles protected from the citation style. A journal style that sets
#' titles in sentence case would otherwise print *Vegan: Community ecology
#' package* and *easypaper: Automate reproducible quarto manuscripts*: the
#' name of the package capitalised as the first word, and the names of other
#' software lowercased. Three things are kept as written, between braces, the
#' way BibTeX protects a word:
#'
#' * the name of the package at the head of its title -- `{vegan}:`;
#' * the software its DESCRIPTION names in single quotes, as CRAN asks --
#'   `{Quarto}`, `{Excel}` -- which knitr writes without the quotes;
#' * R, on its own.
#'
#' The template calls it in the last chunk of `manuscript.qmd`, so the file
#' is written again on every render, with the packages of that render.
#'
#' @param x The packages, by name. `.packages()`, the default, are those
#'   attached in the session that calls it.
#' @param file The `.bib` file to write.
#' @return The path of `file`, invisibly.
#' @export
#' @examples
#' f <- tempfile(fileext = ".bib")
#' write_packages_bib(c("base", "knitr"), f)
#' grep("title", readLines(f), value = TRUE)
#' unlink(f)
write_packages_bib <- function(x = .packages(), file) {
  knitr::write_bib(x, file = file)
  if (file.exists(file)) {
    l <- readLines(file, warn = FALSE, encoding = "UTF-8")
    writeLines(.protect_bib_titles(l), file, useBytes = TRUE)
  }
  invisible(file)
}

#' The title lines of the entries knitr writes, with the names in them
#' protected. Each entry opens with `@Type{R-<package>,`; its title starts
#' with the name of the package, and the package's own DESCRIPTION says, in
#' single quotes, which other names are software.
#' @noRd
.protect_bib_titles <- function(l) {
  pkg <- NA_character_
  for (i in seq_along(l)) {
    key <- regmatches(l[i], regexec("^@[A-Za-z]+\\{R-([^,]+),", l[i]))[[1]]
    if (length(key) == 2L) pkg <- key[2]
    if (!grepl("^\\s*title\\s*=\\s*\\{", l[i])) next
    l[i] <- .protect_title(l[i], if (is.na(pkg)) character(0) else .quoted_names(pkg))
  }
  l
}

#' One title line with its names between braces: the name before the colon
#' at its head, the `names` given, and R on its own. A name already between
#' braces is left as it is, so the line can go through this again.
#' @noRd
.protect_title <- function(line, names = character(0)) {
  # The name at the head: "title = {vegan: ..." -> "title = {{vegan}: ...".
  line <- sub("^(\\s*title\\s*=\\s*\\{)([^{}:]+):", "\\1{\\2}:", line, perl = TRUE)
  for (n in unique(c(names, "R"))) {
    esc <- gsub("([.^$|()\\[\\]*+?\\\\])", "\\\\\\1", n, perl = TRUE)
    # Not inside a word, and not right after a brace: "{Quarto}" is done.
    line <- gsub(paste0("(?<![{A-Za-z0-9])", esc, "(?![A-Za-z0-9])"),
                 paste0("{", n, "}"), line, perl = TRUE)
  }
  line
}

#' The names a package's DESCRIPTION writes in single quotes in its title:
#' the software it names, as CRAN asks ('Quarto', 'Excel'). None for a
#' package that is not installed, or whose title quotes nothing.
#' @noRd
.quoted_names <- function(pkg) {
  t <- tryCatch(suppressWarnings(utils::packageDescription(pkg, fields = "Title")),
                error = function(e) NA)
  if (!is.character(t) || is.na(t)) return(character(0))
  q <- regmatches(t, gregexpr("'[^']+'", t))[[1]]
  unique(gsub("^'|'$", "", q))
}
