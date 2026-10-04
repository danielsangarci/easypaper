# check_species_text(): the scientific names of the text, read the way a
# journal reads them. Never online: the cache answers, as it does offline.

species_project <- function(intro, abstract = "Ants mimic.", methods = "",
                            title = "Mimicry in ants",
                            cache = c("sp:Formica rufa" = "yes",
                                      "sp:Lasius niger" = "yes",
                                      "sp:Fagus sylvatica" = "yes",
                                      "auth:Formica rufa" = "Linnaeus, 1761",
                                      "gen:Formica" = "yes",
                                      "gen:Lasius" = "yes",
                                      "gen:Fagus" = "yes")) {
  p <- new_project(title = title)
  writeLines(c(abstract, "", "**Keywords:** ants, Formica rufa"),
             file.path(p, "_sections", "01_abstract.qmd"))
  writeLines(intro, file.path(p, "_sections", "02_introduction.qmd"))
  writeLines(methods, file.path(p, "_sections", "03_methods.qmd"))
  saveRDS(cache, file.path(p, "references", "species_cache.rds"))
  p
}

species_check <- function(p, ...) {
  old <- options(easypaper.species_offline = TRUE)
  on.exit(options(old))
  suppressWarnings(check_species_text(quiet = TRUE, path = p, ...))
}

problems_at <- function(r, file, line) {
  r$problem[endsWith(r$file, file) & r$line == line]
}

test_that("a name written the way journals ask has nothing to report", {
  p <- species_project(c(
    "Colonies of *Formica rufa* Linnaeus, 1761 were sampled near nests of",
    "*Lasius niger* (Linnaeus, 1758), and *F. rufa* workers attacked *L. niger*,",
    "and _F. rufa_ queens did not.", "",
    "*Formica* spp. were common."),
    abstract = "*Formica rufa* mimics, and *F. rufa* is common.")
  r <- species_check(p)
  expect_identical(nrow(r), 0L)
  expect_identical(attr(r, "species"), c("Formica rufa", "Lasius niger"))
  old <- options(easypaper.species_offline = TRUE)
  on.exit(options(old))
  expect_message(suppressWarnings(check_species_text(path = p)),
                 "Formica rufa, Lasius niger\n  Nothing to change.", fixed = TRUE)
})

test_that("italics: the name, the abbreviation and the genus; sp. in roman", {
  p <- species_project(c(
    "Colonies of *Formica rufa* L. were sampled. Formica rufa workers and",
    "F. rufa queens were counted.", "",
    "Formica workers, *Formica spp.* and *Formica* spp. were seen."),
    title = "Mimicry in Formica rufa")
  r <- species_check(p)
  expect_identical(problems_at(r, "02_introduction.qmd", 1), "not in italics")
  expect_identical(r$fix[endsWith(r$file, "02_introduction.qmd") & r$line == 1],
                   "*Formica rufa*")
  expect_true("not in italics" %in% problems_at(r, "02_introduction.qmd", 2))
  expect_setequal(problems_at(r, "02_introduction.qmd", 4),
                  c("not in italics", "spp. in italics"))
  expect_identical(r$fix[r$problem == "spp. in italics"], "*Formica* spp.")
  # The title, for italics alone.
  expect_identical(problems_at(r, "manuscript.qmd", 2), "not in italics")
})

test_that("in full and with its authority first; abbreviated after that", {
  p <- species_project(c(
    "Colonies of *Formica rufa* (Hymenoptera: Formicidae) were sampled.",
    "Later, workers of *Formica rufa* were counted. *F. rufa* is aggressive,",
    "e.g. *F. rufa* bites."),
    abstract = "*F. rufa* mimics.")
  r <- species_check(p)
  # The abstract is a document of its own: the name in full there too.
  expect_identical(problems_at(r, "01_abstract.qmd", 1), "first mention abbreviated")
  expect_identical(r$fix[endsWith(r$file, "01_abstract.qmd")], "Formica rufa")
  # The higher taxon in parentheses is not an authority; GBIF's is suggested.
  expect_identical(problems_at(r, "02_introduction.qmd", 1),
                   "first mention without its authority")
  expect_identical(r$fix[r$problem == "first mention without its authority"],
                   "Formica rufa Linnaeus, 1761")
  expect_identical(problems_at(r, "02_introduction.qmd", 2),
                   c("in full after its first mention",
                     "abbreviated at the start of a sentence"))
  expect_identical(r$fix[r$problem == "in full after its first mention"], "F. rufa")
  # "e.g." ends with a full stop and no sentence.
  expect_length(problems_at(r, "02_introduction.qmd", 3), 0L)

  # Each rule can be turned off.
  r <- species_check(p, authority = FALSE, abbreviate = FALSE)
  expect_false(any(grepl("authority|after its first|start of a sentence", r$problem)))
  expect_identical(problems_at(r, "01_abstract.qmd", 1), "first mention abbreviated")
  expect_identical(r$fix[endsWith(r$file, "01_abstract.qmd")], "Formica rufa")
})

test_that("two genera with one initial are written in full", {
  p <- species_project(c(
    "*Formica rufa* L. nests under *Fagus sylvatica* L. Workers of",
    "*Formica rufa* climb it, and *F. rufa* eats its seeds."))
  r <- species_check(p)
  expect_identical(problems_at(r, "02_introduction.qmd", 2), "F. could also be Fagus")
  expect_identical(r$fix, "Formica rufa")
})

test_that("only prose is read: code, comments, citations, links, keywords", {
  p <- species_project(c(
    "*Formica rufa* L. nests. Formica rufa workers [@formica_rufa2020] see",
    "<https://example.org/Formica rufa> and [a page](https://x.org/Formica rufa).",
    "<!-- Formica rufa: a comment -->", "",
    "```{r}", "#| fig-cap: \"Nests of *Formica rufa*, in full in a caption.\"",
    "x <- 'Formica rufa'", "```", "",
    "## *Formica rufa* in a heading"))
  r <- species_check(p)
  expect_identical(r$line, 1L)
  expect_identical(r$problem, "not in italics")
  # The keywords line of the abstract is not text.
  expect_false(any(endsWith(r$file, "01_abstract.qmd")))
})

test_that("offline, a pair in italics is taken for a name, and it says so", {
  p <- species_project("*Myrmica rubra* stings, and Myrmica rubra bites.",
                       cache = character())
  old <- options(easypaper.species_offline = TRUE)
  on.exit(options(old))
  expect_warning(r <- check_species_text(quiet = TRUE, path = p),
                 "No connection to GBIF")
  expect_identical(attr(r, "species"), "Myrmica rubra")
  expect_true("not in italics" %in% r$problem)
  # And what is excluded is not a name.
  r <- suppressWarnings(check_species_text(quiet = TRUE, exclude = "Myrmica rubra",
                                           path = p))
  expect_identical(nrow(r), 0L)
})

test_that("authorities and sentences are recognised", {
  expect_true(.has_authority(" Linnaeus, 1761 were"))
  expect_true(.has_authority(" L. were"))
  expect_true(.has_authority(" (Forel, 1874) were"))
  expect_true(.has_authority(" de Geer, 1773"))
  expect_false(.has_authority(" (Hymenoptera: Formicidae) were"))
  expect_false(.has_authority(" (Formicidae)"))
  expect_false(.has_authority(" (red wood ant)"))
  expect_false(.has_authority(" workers were"))
  expect_false(.has_authority(". The"))
  d <- function(x) list(plain = x, txt = x)
  expect_true(.sentence_start(d("First. X"), 8L))
  expect_true(.sentence_start(d("X"), 1L))
  expect_true(.sentence_start(d("End.\n\nX"), 7L))
  expect_false(.sentence_start(d("e.g. X"), 6L))
  expect_false(.sentence_start(d("Smith et al. X"), 14L))
  expect_false(.sentence_start(d("of\nX"), 4L))
  expect_true(.sentence_start(d("- X"), 3L))
})

test_that("it never runs on its own", {
  for (fn in list(render_docx, render_pdf, render_html, make_submission,
                  make_preprint)) {
    expect_no_match(code_of(fn), "check_species_text", fixed = TRUE)
  }
})

test_that("the authority is read from GBIF's answer", {
  local_mocked_bindings(.sp_fetch_json = function(url, ...) {
    list(matchType = "EXACT", rank = "SPECIES",
         scientificName = "Formica rufa Linnaeus, 1761",
         canonicalName = "Formica rufa")
  })
  .sp_state$offline <- FALSE
  expect_identical(.sp_gbif_query("auth", "Formica rufa"), "Linnaeus, 1761")
  local_mocked_bindings(.sp_fetch_json = function(url, ...) {
    list(matchType = "NONE")
  })
  expect_identical(.sp_gbif_query("auth", "Formica nonexistens"), "")
})
