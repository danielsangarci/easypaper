# ---------------------------------------------------------------------------
# make_submission(): builds the folder that goes to the journal and to the data
# repository (Zenodo/Dryad), out of what is already in the project.
#
#   submission/<Journal>/
#     cover_letter_<Journal>.docx      <- template, NOT overwritten if it exists
#     CHECKLIST.md                     <- what has to be done by hand
#     manuscript/
#       title_<Journal>.docx           <- title page (title, authors, counts)
#       main_<Journal>.docx            <- main text, without the supplement
#       supporting_information_<Journal>.docx
#       figures/Figure_1.tiff ...      <- one per figure, 600 dpi, LZW
#     data_and_code/                   <- compendium: data, metadata, code
#     data_and_code.zip
#
# Everything here is REGENERABLE except the cover letter. You can run it as
# many times as you like.
# ---------------------------------------------------------------------------

#' Resolve the {{< include >}} lines and return the full text of a document.
.expand_includes <- function(f) {
  l <- readLines(f, warn = FALSE)
  out <- character(0)
  for (x in l) {
    m <- regmatches(x, regexec("\\{\\{< *include +([^ >]+) *>\\}\\}", x))[[1]]
    out <- c(out, if (length(m) == 2) .expand_includes(here(m[2])) else x)
  }
  out
}

#' Same as .expand_includes() but starting from a character vector.
.expand_includes_text <- function(l) {
  out <- character(0)
  for (x in l) {
    m <- regmatches(x, regexec("\\{\\{< *include +([^ >]+) *>\\}\\}", x))[[1]]
    out <- c(out, if (length(m) == 2) .expand_includes(here(m[2])) else x)
  }
  out
}

#' Numbering of the supplementary material: id -> "Figure S1".
#' Same rule Quarto applies (order of appearance) and the same prefixes, so the
#' text matches the one in the standalone supplementary file.
#' The supplementary content files, in order.
#'
#' Convention: _sections/8*suppl*.qmd. Following the numbering of the other
#' sections -- Results is already 4.1 and 4.2 -- several of them are
#' 8.1_suppl_figures.qmd, 8.2_suppl_methods.qmd.
.suppl_files <- function() {
  sort(list.files(here("_sections"), "^8.*suppl.*[.]qmd$", full.names = TRUE))
}

#' Which of them carry supplementary figures or tables.
#'
#' Nothing to declare: a file is a "floats" file if it defines an sfig or stbl
#' div. The rest are supplementary TEXT (an extended Methods, a longer
#' rationale), which is what you want in its own document so that it carries
#' its own reference list.
.suppl_is_floats <- function(f) {
  any(grepl("\\{#(sfig|stbl)-", readLines(f, warn = FALSE)))
}

.suppl_float_files <- function(files = .suppl_files()) {
  files[vapply(files, .suppl_is_floats, logical(1))]
}

#' Short name of a supplementary file, used in the output file name.
#' "8.2_suppl_methods.qmd" -> "methods"
.suppl_name <- function(f) {
  n <- tools::file_path_sans_ext(basename(f))
  n <- sub("^8[0-9.]*_", "", n)
  n <- sub("^suppl(ementary)?_?", "", n)
  if (nzchar(n)) n else "material"
}

#' crossref block for the k-th file that carries floats, out of n such files.
#'
#' With a single one, numbering is flat: Figure S1, Figure S2. Only when the
#' figures are SPREAD over several documents does the prefix have to carry the
#' appendix -- Figure S1.1, Figure S2.1 -- because Quarto restarts its counter
#' in every document it renders, and two bare "Figure S1" would name two
#' different figures.
.suppl_crossref <- function(k, n, caption_style = "default") {
  cr <- crossref_metadata(caption_style)
  if (n <= 1L) return(cr)
  for (i in seq_along(cr$custom)) {
    key <- cr$custom[[i]]$key
    if (!is.null(key) && key %in% c("sfig", "stbl")) {
      cr$custom[[i]][["reference-prefix"]] <-
        paste0(cr$custom[[i]][["reference-prefix"]], k, ".")
    }
  }
  cr
}

#' Label of every supplementary figure and table, exactly as the reader sees
#' it. This is what replaces @sfig-x in the main text when the floats are NOT
#' in that document.
.suppl_numbering <- function(caption_style = "default") {
  files <- .suppl_float_files()
  out <- character(0)
  for (k in seq_along(files)) {
    pref <- list(sfig = "Figure S", stbl = "Table S")
    for (kind in .suppl_crossref(k, length(files), caption_style)$custom) {
      if (!is.null(kind$key)) pref[[kind$key]] <- kind[["reference-prefix"]]
    }
    txt <- readLines(files[k], warn = FALSE)
    ids <- unlist(regmatches(txt, gregexpr("(?<=\\{#)(sfig|stbl)-[A-Za-z0-9_:.-]+",
                                           txt, perl = TRUE)))
    n <- list(sfig = 0L, stbl = 0L)
    for (id in ids) {
      kind <- sub("-.*$", "", id)
      n[[kind]] <- n[[kind]] + 1L
      out[id] <- paste0(pref[[kind]], n[[kind]])
    }
  }
  out
}

#' Wrapper for one supplementary file: supplementary.qmd with its include
#' swapped and its title turned into "Appendix Sk". Only used when there is
#' more than one supplementary document.
.build_supplementary <- function(section, k, n = 1L) {
  l <- readLines(here("supplementary.qmd"), warn = FALSE)
  inc <- grep("\\{\\{< *include +_sections/8", l)
  if (!length(inc)) {
    stop("supplementary.qmd does not include any _sections/8*.qmd file.",
         call. = FALSE)
  }
  l[inc[1]] <- sprintf("{{< include _sections/%s >}}", basename(section))
  # Drop any FURTHER supplementary include: each appendix is its own document.
  # Guarded, because l[-integer(0)] returns an empty vector, not l.
  if (length(inc) > 1L) l <- l[-inc[-1]]
  # With a single supplementary document its own title stands ("Supporting
  # Information"); with several, each one is named after its appendix.
  if (n > 1L) {
    ttl <- grep("^title:", l)
    if (length(ttl)) l[ttl[1]] <- sprintf('title: "Appendix S%d"', k)
  }
  dest <- here(sprintf("tmp_supplementary_S%d.qmd", k))
  writeLines(l, dest)
  dest
}


#' Self-contained document holding the main text WITHOUT the supplement.
#'
#' @param blinded TRUE removes the title block (title, authors, affiliations and
#'   correspondence) so the main text starts at the Abstract. That is what
#'   journals with double-blind review ask for, and the reason the title page is
#'   generated as a separate document. Careful: the Acknowledgements and CRediT
#'   sections are NOT touched and also identify you; review them yourself.
#'
#' This is done here and not with a Lua filter because Quarto resolves
#' cross-references after user filters: once the target is cut, the @sfig-x
#' citations would be left as "?@sfig-x" in the .docx that goes to the journal.
#' Verified. Here they are replaced by their text ("Figure S1") before
#' compiling.
.build_main_text <- function(journal, caption_style, fmt = "docx",
                             blinded = FALSE, suppl_figures = "separate") {
  suppl_figures <- match.arg(suppl_figures, c("separate", "main"))
  txt <- readLines(MASTER, warn = FALSE)

  # Blinded: drop the affiliations and the correspondence line from the body.
  # Title, authors and date come from the YAML, further down.
  if (blinded) {
    a <- grep("0_authors\\.qmd", txt)
    if (length(a)) txt <- txt[-a]
  }

  # 1) decide what supplementary content stays in this document.
  #    suppl_figures = "main"     -> the figures and tables stay at the end,
  #                                  and Quarto numbers them Figure S1 itself
  #    suppl_figures = "separate" -> nothing stays; the citations to them are
  #                                  replaced by their text further down
  #    Supplementary TEXT (extended Methods and the like) always leaves: its
  #    whole point is a document with its own reference list.
  files  <- .suppl_files()
  floats <- .suppl_float_files(files)
  keep   <- if (suppl_figures == "main") floats else character(0)
  cut    <- setdiff(files, keep)

  drop <- unlist(lapply(basename(cut), function(f) grep(f, txt, fixed = TRUE)))
  if (!length(keep)) {
    # Nothing supplementary stays: the section header goes too, together with
    # the blank lines and the pagebreak before it.
    i <- grep("^#\\s+Supporting information\\s*$", txt)
    if (length(i) != 1) {
      stop("Cannot find exactly one '# Supporting information' header in ",
           basename(MASTER), call. = FALSE)
    }
    drop <- unique(c(i, drop))
    k <- i - 1L
    while (k >= 1 && (!nzchar(trimws(txt[k])) || grepl("pagebreak", txt[k]))) {
      drop <- c(drop, k); k <- k - 1L
    }
  }
  if (length(drop)) txt <- txt[-drop]

  # 2) resolve the includes and replace the citations to the supplement
  body <- .expand_includes_text(txt)
  if (!length(keep) && any(grepl("\\{\\{< *include +_sections/8", body))) {
    stop("The main text still includes a supplementary file. Check the ",
         "'# Supporting information' section of ", basename(MASTER), ".",
         call. = FALSE)
  }
  # Only what LEFT the document needs its citations rewritten. Whatever stays
  # is resolved by Quarto itself, natively.
  numbers <- if (length(keep)) character(0) else .suppl_numbering(caption_style)
  # Longest ids first: with @sfig-map and @sfig-map-detail both defined, the
  # short one must not eat the start of the long one.
  for (id in names(numbers)[order(-nchar(names(numbers)))]) {
    # [@sfig-x] -> (Figure S1)   |   @sfig-x -> Figure S1
    body <- gsub(paste0("\\[@", id, "\\]"), paste0("(", numbers[[id]], ")"),
                 body, perl = TRUE)
    # The trailing lookaheads stop the match halfway through a longer id, while
    # still allowing the sentence-final "@stbl-raw." -- a dot only belongs to
    # the id when a letter or a digit follows it.
    body <- gsub(paste0("(?<![A-Za-z0-9_])@", id, "(?![A-Za-z0-9_:-])(?!\\.[A-Za-z0-9_])"),
                 numbers[[id]], body, perl = TRUE)
  }

  # 3) self-contained YAML header: the temporary file is not in the render:
  #    list of _quarto.yml, so it does not inherit the project configuration.
  yml <- yaml::read_yaml(here("_quarto.yml"))
  yml$project <- NULL
  yml$csl <- here("references_styles", paste0(journal, ".csl"))
  yml$crossref <- crossref_metadata(caption_style)
  yml$format <- yml$format[fmt]
  own <- rmarkdown::yaml_front_matter(MASTER)
  for (nm in names(own)) yml[[nm]] <- own[[nm]]
  if (blinded) {
    # Without these fields Quarto writes no title block: the document starts
    # straight at the Abstract.
    for (nm in c("title", "author", "date", "date-format")) yml[[nm]] <- NULL
  }

  # The yaml package writes logicals as yes/no (YAML 1.1) and Quarto uses
  # YAML 1.2, which only accepts true/false.
  as_bool <- function(x) structure(ifelse(x, "true", "false"), class = "verbatim")

  end <- grep("^---\\s*$", body)[2]
  dest <- here("tmp_main_text.qmd")
  writeLines(c("---",
               trimws(yaml::as.yaml(yml, handlers = list(logical = as_bool)),
                      which = "right"), "---",
               body[(end + 1):length(body)]), dest)
  dest
}

#' Standalone figures, renumbered and in the format the journal asks for.
#' The order is the order of appearance in _sections/6_figures.qmd, which is
#' the same one Quarto uses to number them.
.export_figures <- function(dest, format = "tiff") {
  txt <- readLines(here("_sections/6_figures.qmd"), warn = FALSE)
  labs <- regmatches(txt, regexpr("(?<=^#\\| label: )fig-[A-Za-z0-9_:.-]+",
                                  txt, perl = TRUE))
  if (!length(labs)) return(invisible(character(0)))
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)

  written <- character(0)
  for (i in seq_along(labs)) {
    src <- here("figures", format, paste0(labs[i], "-1.", format))
    if (!file.exists(src)) {
      warning("Missing figure ", basename(src),
              ": render the manuscript first.", call. = FALSE)
      next
    }
    # They are already converted by export_figure_formats(): all that happens
    # here is the renumbering to the order the reader sees.
    out <- file.path(dest, sprintf("Figure_%d.%s", i, format))
    file.copy(src, out, overwrite = TRUE)
    written <- c(written, out)
  }
  message("Figures exported: ", length(written), " -> ", basename(dest), "/")
  invisible(written)
}

#' Packages that produced something the compendium contains.
#'
#' renv's default scan walks the whole project, so trackdown -- which only
#' syncs drafts with Google Docs -- ends up in the lockfile of a data deposit.
#' The rule here is narrower but not arbitrary: a package belongs in the lock
#' if its output travels. That is the analysis (manuscript, sections, setup),
#' the .csv conversion (xlsx_to_csv.R -> data/processed/) and the metadata
#' (create_metadata.R -> metadata/), even though those last two scripts are
#' not themselves published. Left out: trackdown, and the build tooling
#' (make.R, submission.R, crossref_styles.R, renv_setup.R), which produce
#' nothing that ships.
#'
#' renv adds the recursive dependencies of whatever is listed, so nothing
#' breaks: flextable still drags officer in, dataspice still drags EML in.
.analysis_packages <- function() {
  files <- c(MASTER, here("supplementary.qmd"), here("title_page.qmd"),
             list.files(here("_sections"), "[.]qmd$", full.names = TRUE),
             here("R/setup.R"),
             here("R/xlsx_to_csv.R"), here("R/create_metadata.R"),
             list.files(here("R"), "^analysis.*[.]R$", full.names = TRUE))
  files <- files[file.exists(files)]
  p <- tryCatch(sort(unique(renv::dependencies(files, quiet = TRUE)$Package)),
                error = function(e) character(0))
  setdiff(p, rownames(utils::installed.packages(priority = "base")))
}

#' Data and code compendium, ready for Zenodo/Dryad.
.export_data_code <- function(dest, blinded = TRUE) {
  unlink(dest, recursive = TRUE)
  dir.create(file.path(dest, "data"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(dest, "scripts"), showWarnings = FALSE)

  # Only the open formats are published: the .csv, never the source .xlsx.
  # The originals stay in the private project as the archive copy; a .csv is
  # plain text and will still be readable when nothing opens an .xlsx.
  if (dir.exists(here("data/processed"))) {
    file.copy(here("data/processed"), file.path(dest, "data"), recursive = TRUE)
  }
  if (file.exists(here("data/README.md"))) {
    file.copy(here("data/README.md"), file.path(dest, "data"), overwrite = TRUE)
  }
  non_open <- list.files(file.path(dest, "data"), recursive = TRUE,
                         pattern = "[.](xlsx|xls|sav|dta|mdb|accdb)$",
                         ignore.case = TRUE, full.names = TRUE)
  if (length(non_open)) {
    unlink(non_open)
    message("Removed from the compendium (non-open format): ",
            paste(basename(non_open), collapse = ", "))
  }
  if (dir.exists(here("data/metadata"))) {
    file.copy(here("data/metadata"), dest, recursive = TRUE)
  }
  # Only the statistical analysis and the setup it needs. Everything else in R/
  # is authoring tooling -- building the submission, syncing with Google Docs,
  # converting spreadsheets, writing metadata, managing dependencies. That is
  # how the paper was made, not how the results were obtained, and it is noise
  # for whoever downloads the compendium to reproduce them.
  #
  # This is a whitelist on purpose: a tooling script added to R/ later stays out
  # by default instead of leaking into the submission. To publish an extra
  # analysis script, name it R/analysis_*.R and it is picked up automatically.
  scripts <- c(here("R/setup.R"),
               list.files(here("R"), "^analysis.*[.]R$", full.names = TRUE))
  scripts <- scripts[file.exists(scripts)]
  file.copy(scripts, file.path(dest, "scripts"), overwrite = TRUE)
  for (f in c("output/supplementary/analysis_code.R",
              "output/supplementary/sessionInfo.txt")) {
    if (file.exists(here(f))) file.copy(here(f), file.path(dest, "scripts"),
                                        overwrite = TRUE)
  }
  # The project README documents how the PAPER is built (sections, journals,
  # trackdown): noise for whoever downloads this. The compendium gets its own,
  # written from what the folder actually holds.
  for (f in c("LICENSE", "LICENSE-CODE", "renv.lock",
              list.files(here(), "\\.Rproj$"))) {
    if (file.exists(here(f))) file.copy(here(f), dest, overwrite = TRUE)
  }
  check_renv(quiet = TRUE)   # warns if it is missing or out of sync

  # No .Rproj.user, .Rhistory or .DS_Store in what gets published.
  .write_data_readme(dest, blinded = blinded)

  junk <- list.files(dest, pattern = "^([.]Rhistory|[.]DS_Store|[.]gitkeep|[.]Rproj[.]user)$",
                     recursive = TRUE, all.files = TRUE, full.names = TRUE,
                     include.dirs = TRUE)
  unlink(junk, recursive = TRUE)
  invisible(dest)
}

#' Read a dataspice .csv from the compendium, or NULL if it is not there.
.spice <- function(dest, file) {
  f <- file.path(dest, "metadata", file)
  if (!file.exists(f)) return(NULL)
  d <- tryCatch(utils::read.csv(f, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(d) || !nrow(d)) NULL else d
}

#' Canned descriptions for the files this template always produces. Anything
#' else is described by its own first comment line, so a script you add
#' documents itself here without touching this function.
.known_desc <- c(
  "dataspice.json"       = "Machine-readable metadata (Schema.org standard).",
  "attributes.csv"       = "Data dictionary: column names, descriptions and units for every data file.",
  "access.csv"           = "Registry of the files included in the dataset and their formats.",
  "biblio.csv"           = "Dataset-level information: title, description, temporal and spatial coverage.",
  "creators.csv"         = "Author information and affiliations.",
  "index_metadata.html"  = "OPEN THIS FILE in your web browser to view a visual map of all variables and units.",
  "index.html"           = "OPEN THIS FILE in your web browser to view a visual map of all variables and units.",
  "analysis_code.R"      = "Full statistical analysis of the manuscript, in the order it is executed. Extracted from the manuscript sources.",
  "setup.R"              = "Seed, colour palette and helper functions loaded before the analysis.",
  "sessionInfo.txt"      = "Exact versions of R, of every package and of Quarto used to produce the reported results."
)

#' First comment line of a script, used as its description.
.first_comment <- function(f) {
  l <- readLines(f, warn = FALSE, n = 40)
  l <- l[grepl("^\\s*#", l)]
  l <- trimws(sub("^\\s*#+'?\\s*", "", l))
  l <- l[nzchar(l) & !grepl("^-{3,}|^={3,}", l)]
  if (length(l)) l[1] else ""
}

#' Describe a data file: its dataspice title if there is one, plus dimensions.
.describe_data <- function(f, access) {
  dims <- tryCatch({
    d <- utils::read.csv(f, check.names = FALSE, stringsAsFactors = FALSE)
    sprintf("%d rows x %d columns", nrow(d), ncol(d))
  }, error = function(e) NA_character_)
  ttl <- NA_character_
  if (!is.null(access) && "fileName" %in% names(access) && "name" %in% names(access)) {
    i <- match(basename(f), access$fileName)
    if (!is.na(i)) ttl <- access$name[i]
  }
  parts <- c(if (!is.na(ttl) && nzchar(ttl)) ttl, if (!is.na(dims)) dims)
  paste(parts, collapse = " -- ")
}

#' README.txt of the compendium, written from what the folder ACTUALLY holds.
#'
#' Nothing here is hard-coded to one paper: the title comes from the YAML of
#' manuscript.qmd, the dates from the dataspice metadata, and every file is
#' listed and described by inspecting it. Fill the metadata once with
#' R/create_metadata.R and this file writes itself, submission after
#' submission, with no editing.
.write_data_readme <- function(dest, blinded = TRUE) {
  own    <- rmarkdown::yaml_front_matter(MASTER)
  title  <- if (!is.null(own$title)) own$title else "Untitled"
  access <- .spice(dest, "access.csv")
  biblio <- .spice(dest, "biblio.csv")

  # Authors: never named when the submission is blinded.
  authors <- "Anonymous"
  if (!blinded) {
    authors <- tryCatch(paste(.author_names(), collapse = ", "),
                        error = function(e) "Anonymous")
  }

  # Date of data collection: dataspice startDate/endDate if they were filled in.
  dates <- NULL
  if (!is.null(biblio)) {
    sd <- if ("startDate" %in% names(biblio)) biblio$startDate[1] else NA
    ed <- if ("endDate"   %in% names(biblio)) biblio$endDate[1]   else NA
    sd <- if (!is.na(sd) && nzchar(sd)) substr(sd, 1, 4) else NA
    ed <- if (!is.na(ed) && nzchar(ed)) substr(ed, 1, 4) else NA
    if (!is.na(sd)) dates <- if (!is.na(ed) && ed != sd) paste0(sd, "-", ed) else sd
  }

  rule <- strrep("-", 72)
  sec  <- function(name, dir, describe) {
    fs <- sort(list.files(dir, all.files = FALSE))
    fs <- fs[!fs %in% c(".gitkeep", ".DS_Store", "README.md", "README.txt")]
    if (!length(fs)) return(c(name, "   (empty)", ""))
    c(name,
      unlist(lapply(fs, function(f) {
        d <- describe(file.path(dir, f))
        if (!nzchar(d)) sprintf("   - %s", f)
        else strwrap(sprintf("%s: %s", f, d), width = 76,
                     initial = "   - ", prefix = "     ")
      })),
      "")
  }

  n <- 0L; num <- function() { n <<- n + 1L; n }
  general <- c(
    "GENERAL INFORMATION", "",
    strwrap(sprintf("%d. Title: %s", num(), title), width = 76, exdent = 3),
    if (!is.null(dates)) sprintf("%d. Date of data collection: %s", num(), dates),
    sprintf("%d. Authors Information:", num()), "",
    paste0("   ", authors), ""
  )

  overview <- c(
    "FILE OVERVIEW", "",
    strwrap(paste("This repository holds the data, the metadata describing it and the",
                  "code that produced the results reported in the manuscript. It is",
                  "organized into three folders:"), width = 76), "",
    sec("A) data/processed",
        file.path(dest, "data", "processed"),
        function(f) .describe_data(f, access)),
    sec("B) metadata",
        file.path(dest, "metadata"),
        function(f) {
          d <- .known_desc[basename(f)]
          if (is.na(d)) "" else unname(d)
        }),
    sec("C) scripts",
        file.path(dest, "scripts"),
        function(f) {
          d <- .known_desc[basename(f)]
          if (!is.na(d)) return(unname(d))
          if (grepl("[.]R$", f)) .first_comment(f) else ""
        }),
    strwrap(paste("Data are distributed as .csv: plain text, readable by any software,",
                  "and still readable when today's spreadsheet formats are not. The",
                  "original spreadsheets are not part of this deposit; the .csv are a",
                  "faithful copy of them."), width = 76), ""
  )

  has_lock <- file.exists(file.path(dest, "renv.lock"))
  rproj    <- list.files(dest, pattern = "[.]Rproj$")
  rproj    <- if (length(rproj)) rproj[1] else "the .Rproj file"
  repro <- c(
    "REPRODUCIBILITY (SOFTWARE ENVIRONMENT)", "",
    if (has_lock) c(
      strwrap(paste("This project uses the R package 'renv' to make the statistical",
                    "analysis reproducible. The 'renv.lock' file lists the exact",
                    "version of every package used in this study."), width = 76), "",
      "To reconstruct the analysis environment:", "",
      sprintf("1. Open the project file ('%s') to launch RStudio.", rproj),
      "2. If 'renv' is not installed on your system, run in the R console:",
      "      install.packages(\"renv\")",
      "3. Restore the environment by running:",
      "      renv::restore()",
      strwrap(paste("(this reads 'renv.lock' and installs the recorded package",
                    "versions, without touching your own R library)."),
              width = 76, initial = "   ", prefix = "   "), "",
      strwrap(paste("Run 'scripts/analysis_code.R'. It sources 'scripts/setup.R'",
                    "and reproduces the analyses reported in the manuscript."),
              width = 76, initial = "4. ", prefix = "   "), ""
    ) else c(
      strwrap(paste("The versions of R, of every package and of Quarto used to",
                    "produce the reported results are recorded in",
                    "'scripts/sessionInfo.txt'."), width = 76), "",
      strwrap(paste("Run 'scripts/analysis_code.R'. It sources 'scripts/setup.R' and",
                    "reproduces the analyses reported in the manuscript."),
              width = 76), ""
    )
  )

  licence <- c(
    "LICENSE", "",
    strwrap(paste("Data and metadata: CC BY 4.0 (see LICENSE). Code: MIT (see",
                  "LICENSE-CODE). Both allow reuse with attribution; please cite the",
                  "associated publication."), width = 76), ""
  )

  writeLines(c(general, rule, "", overview, rule, "", repro, rule, "", licence),
             file.path(dest, "README.txt"))
  invisible(file.path(dest, "README.txt"))
}

#' Title page carrying the title of the manuscript.
#'
#' title_page.qmd has a `title:` of its own, and in Quarto the document's own
#' front matter WINS over the metadata passed to quarto_render(). Rendering it
#' directly would therefore keep whatever title that file happens to hold,
#' silently disagreeing with the manuscript. A copy with the line rewritten
#' from the master avoids it.
.build_title_page <- function() {
  l   <- readLines(here("title_page.qmd"), warn = FALSE)
  own <- rmarkdown::yaml_front_matter(MASTER)
  i   <- grep("^title:", l)
  if (length(i) && !is.null(own$title)) {
    l[i[1]] <- sprintf('title: "%s"', gsub('"', '\\\\"', own$title))
  }
  dest <- here("tmp_title_page.qmd")
  writeLines(l, dest)
  dest
}

#' Blank cover letter with the usual structure. Never overwrites an existing one.
.write_cover_letter <- function(dest, journal_name) {
  if (file.exists(dest)) {
    message("Cover letter already exists, left untouched: ", basename(dest))
    return(invisible(dest))
  }
  tmp <- here("tmp_cover_letter.qmd")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(c(
    "---", sprintf('title: "Cover letter -- %s"', journal_name),
    "format:", "  docx:",
    "    reference-doc: format/word_plain_paper_style.docx", "---", "",
    "[Date]", "", "Dear Editor,", "",
    "We are pleased to submit our manuscript entitled *\"[TITLE]\"* for",
    sprintf("consideration as [article type] in *%s*.", journal_name), "",
    "**What we did.** [One or two sentences: question and approach.]", "",
    "**What we found.** [The main result, with the number.]", "",
    sprintf("**Why %s.** [Why it fits the scope and the readership.]", journal_name), "",
    "The manuscript is original, is not under consideration elsewhere, and all",
    "authors have approved the submission. We declare no conflict of interest.",
    "Data and code are available at [repository DOI].", "",
    "Suggested reviewers: [Name, affiliation, e-mail] (x3).", "",
    "Yours sincerely,", "", "[Corresponding author, on behalf of all authors]"
  ), tmp)
  quarto::quarto_render(tmp, output_format = "docx", as_job = FALSE, quiet = TRUE)
  file.rename(sub("\\.qmd$", ".docx", tmp), dest)
  invisible(dest)
}

.write_checklist <- function(dest, journal_name, label) {
  writeLines(c(
    sprintf("# Submission checklist -- %s", journal_name), "",
    "Generated by `make_submission()`. Nothing below is produced automatically.", "",
    "## Before submitting", "",
    sprintf("- [ ] Cover letter written (`cover_letter_%s.docx`).", label),
    "- [ ] Title page: running head, word count, number of figures and tables,",
    "      ORCID of every author, funding.",
    "- [ ] Suggested reviewers (usually 3, with no conflict of interest).",
    "- [ ] Check the figure format the journal requires (TIFF/EPS/PDF, minimum",
    "      dpi, width in mm) and regenerate if needed:",
    "      `make_submission(figure_format = \"png\")`.",
    "- [ ] `renv.lock` present in `data_and_code/`: without it the package",
    "      versions are not recorded. `renv::snapshot()` if it is missing.",
    "- [ ] Upload `data_and_code.zip` to Zenodo/Dryad and put the DOI in the",
    "      Data availability statement of the manuscript.",
    "- [ ] `git tag submission-1`", "",
    "## Journal dependent", "",
    "- [ ] Graphical abstract / highlights.",
    "- [ ] Double blind: the title block is already out of `main_*.docx` (it is",
    "      generated with blinded = TRUE). But review Acknowledgements and",
    "      CRediT, which also identify you, and self-citations of the kind",
    "      \"in our previous study (Author et al.)\".",
    "- [ ] Line numbers and double spacing, if they ask for them.", "",
    "## Regenerable", "",
    "Everything else is rebuilt by `make_submission()`. The cover letter is",
    "never overwritten."
  ), dest)
  invisible(dest)
}

#' Build the complete submission folder.
#'
#' @param journal   name of the .csl (see list_journals())
#' @param label     name of the folder inside submission/ and the suffix of
#'                  every file in it. Defaults to "default": a trial run is
#'                  then obviously a trial run, and it cannot be mistaken for
#'                  a real submission to a journal you never chose. Pass the
#'                  journal name when the submission is the real one.
#' @param figure_format one of FIG_FORMATS: "tiff", "png" or "jpg"
#' @param snapshot TRUE (the default) runs renv::snapshot() before building the
#'   compendium, so the renv.lock that travels in the zip describes exactly the
#'   environment THIS submission came out of. It does not need renv::init():
#'   snapshot scans the project code and records the version of each package
#'   from the library you are actually using. Set it to FALSE if you maintain
#'   renv.lock by hand and do not want it rewritten.
#' @param suppl_figures where the supplementary figures and tables go.
#'   "separate" (the default) leaves them in their own document and rewrites
#'   the citations in the main text: @sfig-map becomes "Figure S1". "main"
#'   keeps them at the end of main_*.docx, where Quarto numbers and resolves
#'   them natively. Either way they are cited from the main text. Supplementary
#'   TEXT (an extended Methods) always goes out as its own document, with its
#'   own reference list.
#' @param blinded TRUE (the default) splits the manuscript the way journals with
#'   double-blind review ask for: the title page runs from the title to just
#'   before the Abstract, and the main text starts at the Abstract, with no
#'   authors.
make_submission <- function(journal = "myrmecological-news", label = "default",
                            caption_style = "default", figure_format = "tiff",
                            blinded = TRUE, snapshot = TRUE,
                            suppl_figures = "separate") {
  figure_format <- match.arg(figure_format, FIG_FORMATS)
  if (is.null(label) || !nzchar(label)) label <- "default"
  root <- here("submission", label)
  man  <- file.path(root, "manuscript")
  dir.create(man, recursive = TRUE, showWarnings = FALSE)

  .check_quarto(); .check_license(); sync_licenses(quiet = TRUE)
  check_citations(); check_crossrefs(quiet = TRUE); check_title(quiet = TRUE)

  # 1) main text, without the supplement
  suppl_figures <- match.arg(suppl_figures, c("separate", "main"))
  f <- .render("docx", journal, caption_style, "docx", split = TRUE,
               blinded = blinded, suppl_figures = suppl_figures)
  file.rename(f, file.path(man, sprintf("main_%s.docx", label)))

  # 2) title page, with title and authors taken from the manuscript
  own <- rmarkdown::yaml_front_matter(MASTER)
  tp  <- .build_title_page()
  on.exit(unlink(c(tp, sub("[.]qmd$", ".docx", tp))), add = TRUE)
  quarto::quarto_render(tp, output_format = "docx",
                        metadata = list(author = own$author), as_job = FALSE)
  # Not in the render: list, so Quarto leaves the output next to the input.
  file.copy(sub("[.]qmd$", ".docx", tp),
            file.path(man, sprintf("title_%s.docx", label)), overwrite = TRUE)

  # 3) standalone supplement(s). With suppl_figures = "main" the figures and
  #    tables are already at the end of main_*.docx, so only the supplementary
  #    TEXT is rendered on its own -- which is where the independent reference
  #    list matters.
  all_suppl <- .suppl_files()
  to_render <- if (suppl_figures == "main") setdiff(all_suppl, .suppl_float_files(all_suppl))
               else all_suppl
  sup <- render_supplementary(journal, caption_style, files = to_render)
  for (i in seq_along(sup)) {
    nm <- if (length(sup) == 1L) sprintf("supporting_information_%s.docx", label)
          else sprintf("supporting_information_%s_%s.docx",
                       .suppl_name(to_render[i]), label)
    file.copy(sup[i], file.path(man, nm), overwrite = TRUE)
  }

  # 4) standalone figures and the compendium
  .export_figures(file.path(man, "figures"), figure_format)
  export_code()
  # The lockfile is written HERE, at submission time, and not on every render:
  # this is the output it has to describe. renv::init() is not required --
  # snapshot reads the project code and records what your library holds.
  if (isTRUE(snapshot)) {
    if (!requireNamespace("renv", quietly = TRUE)) {
      warning("renv is not installed, so the compendium goes out without a ",
              "renv.lock. install.packages(\"renv\") and rebuild.",
              call. = FALSE, immediate. = TRUE)
    } else {
      pkgs <- .analysis_packages()
      message("renv::snapshot(): recording the environment of THIS submission (",
              length(pkgs), " direct dependencies of the analysis).")
      if (length(pkgs)) {
        renv::snapshot(project = here(), packages = pkgs, prompt = FALSE)
      } else {
        # Nothing detected (an empty template): record everything rather than
        # ship a lockfile that promises less than the paper needs.
        renv::snapshot(project = here(), prompt = FALSE)
      }
    }
  }
  dc <- file.path(root, "data_and_code")
  .export_data_code(dc, blinded = blinded)
  zip::zip(file.path(root, "data_and_code.zip"), basename(dc), root = root)

  # 5) what is written by hand
  .write_cover_letter(file.path(root, sprintf("cover_letter_%s.docx", label)), label)
  .write_checklist(file.path(root, "CHECKLIST.md"), label, label)
  unlink(file.path(OUTPUT, "figures"), recursive = TRUE)

  message("\nSubmission folder ready: ", root)
  invisible(root)
}

#' What goes where, written into the preprint deposit itself.
#' @noRd
.write_preprint_readme <- function(dest, label) {
  own <- rmarkdown::yaml_front_matter(MASTER)
  title <- if (!is.null(own$title)) own$title else "Untitled"
  writeLines(c(
    sprintf("# Preprint deposit: %s", title),
    "",
    sprintf("Built by `make_preprint()` on %s. Two destinations, one folder.",
            format(Sys.Date())),
    "",
    "## To the preprint server (bioRxiv, EcoEvoRxiv, PCI Ecology...)",
    "",
    sprintf("- `manuscript/preprint_%s.pdf` -- the manuscript, signed: the", label),
    "  authors are on the front page. A preprint is not reviewed blind, so this",
    "  is deliberately NOT the blinded document `make_submission()` builds.",
    "- `manuscript/supporting_information*.pdf` -- upload as supplementary files.",
    "- `manuscript/figures/` -- only if the server asks for figures separately.",
    "  The PDF already embeds them at full resolution.",
    "",
    "## To the data repository (Zenodo, Dryad, figshare...)",
    "",
    "- `data_and_code.zip` -- data, metadata, the analysis code, the licences",
    "  and `renv.lock`. It has its own README, written from what it holds.",
    "",
    "## Before you press submit",
    "",
    "- [ ] Deposit the data and code FIRST: you need its DOI to cite it in the",
    "      manuscript, and editing a preprint after posting is a new version.",
    "- [ ] The DOI, written into the manuscript (\"Data and code are available",
    "      at https://doi.org/...\") and rebuilt before uploading the PDF.",
    "- [ ] Licences: the code travels MIT, the text and data CC BY 4.0. Say so",
    "      in the repository's licence field, which is a separate declaration.",
    "- [ ] ORCID for every author, on the server's form.",
    "- [ ] Competing interests and funding, if the server asks for them.",
    "- [ ] Check the journal you plan to submit to accepts preprints. Most",
    "      ecology journals do; a few still do not, and posting first would",
    "      close that door."
  ), dest)
  invisible(dest)
}

#' Build a preprint deposit: the manuscript as a signed PDF, its supplement,
#' its figures, and the data and code compendium -- everything a preprint
#' server and a data repository ask for between them.
#'
#' This is `make_submission()`'s sibling, and the differences are the point.
#' The manuscript comes out as ONE signed PDF, not a blinded pair of Word
#' files: a preprint carries its authors, and there is no editor to write a
#' cover letter to. Everything else -- the standalone figures, the compendium,
#' the lockfile -- is the same machinery, because a deposit has to stand on its
#' own just as hard as a submission does.
#'
#' @param journal the .csl the citations come out in. A preprint has no house
#'   style, so this is only about which convention you prefer to read.
#' @param label names the folder inside submission/ and every file in it.
#'   Defaults to the server you are most likely to post to; change it for
#'   another one, or for a second version.
#' @param caption_style default | abbrev | nature | compact.
#' @param figure_format standalone figures: "tiff", "png" or "jpg".
#' @param snapshot TRUE records renv.lock before building the compendium.
#' @param suppl_figures "separate" leaves the supplementary figures and tables
#'   in their own document; "main" keeps them at the end of the manuscript.
#' @return the path of the deposit, invisibly.
make_preprint <- function(journal = "myrmecological-news", label = "bioRxiv",
                          caption_style = "default", figure_format = "tiff",
                          snapshot = TRUE, suppl_figures = "separate") {
  figure_format <- match.arg(figure_format, FIG_FORMATS)
  suppl_figures <- match.arg(suppl_figures, c("separate", "main"))
  if (is.null(label) || !nzchar(label)) label <- "bioRxiv"
  root <- here("submission", label)
  man  <- file.path(root, "manuscript")
  dir.create(man, recursive = TRUE, showWarnings = FALSE)

  .check_quarto(); .check_license(); sync_licenses(quiet = TRUE)
  check_citations(); check_crossrefs(quiet = TRUE); check_title(quiet = TRUE)

  # 1) the manuscript, as one signed PDF. split = TRUE takes the supplement
  #    out; blinded = FALSE keeps the title block, which is the whole
  #    difference from a submission.
  f <- .render("pdf", journal, caption_style, "pdf", split = TRUE,
               blinded = FALSE, suppl_figures = suppl_figures)
  file.rename(f, file.path(man, sprintf("preprint_%s.pdf", label)))

  # 2) the supplement(s), also as PDF: a server takes one file per document.
  all_suppl <- .suppl_files()
  to_render <- if (suppl_figures == "main") {
                 setdiff(all_suppl, .suppl_float_files(all_suppl))
               } else all_suppl
  sup <- render_supplementary(journal, caption_style, output_format = "pdf",
                              files = to_render)
  for (i in seq_along(sup)) {
    nm <- if (length(sup) == 1L) sprintf("supporting_information_%s.pdf", label)
          else sprintf("supporting_information_%s_%s.pdf",
                       .suppl_name(to_render[i]), label)
    file.copy(sup[i], file.path(man, nm), overwrite = TRUE)
  }

  # 3) figures on their own, the code, and the environment they ran in
  .export_figures(file.path(man, "figures"), figure_format)
  export_code()
  if (isTRUE(snapshot)) .record_env()

  # 4) the compendium, never blinded: a preprint deposit is signed
  dc <- file.path(root, "data_and_code")
  .export_data_code(dc, blinded = FALSE)
  zip::zip(file.path(root, "data_and_code.zip"), basename(dc), root = root)

  # 5) what is left to do by hand
  .write_preprint_readme(file.path(root, "README.md"), label)
  unlink(file.path(OUTPUT, "figures"), recursive = TRUE)

  message("\nPreprint deposit ready: ", root)
  invisible(root)
}
