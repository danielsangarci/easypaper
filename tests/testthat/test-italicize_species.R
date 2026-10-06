# Every test here runs offline. GBIF and Wikipedia are asked nothing: the
# answers the fixtures need are in fixtures/italicize_species/cache.rds, and
# the option easypaper.species_offline makes any question that is not answered
# there fail at once rather than reach the network -- so a test that starts
# needing a new answer fails, instead of quietly going online. The fixtures
# are regenerated, with a connection, by dev/species_fixtures.R.

fx <- function(...) test_path("fixtures", "italicize_species", ...)

# A copy of the cache: the function writes to the one it is given.
copy_cache <- function() {
  f <- tempfile(fileext = ".rds")
  file.copy(fx("cache.rds"), f)
  f
}

skip_if_no_pandoc <- function() {
  ok <- tryCatch({ easypaper:::.sp_find_pandoc(); TRUE }, error = function(e) FALSE)
  skip_if_not(ok, "pandoc is not available")
}

# What a title has in italics, one element per italic run.
italics <- function(s) {
  s <- gsub("</?span[^>]*>", "", s)
  regmatches(s, gregexpr("(?<=<i>)[^<]*(?=</i>)", s, perl = TRUE))[[1]]
}

titles_of <- function(json) {
  items <- jsonlite::read_json(json)
  structure(lapply(items, function(x) x$title),
            names = vapply(items, function(x) x$id, ""))
}

test_that("every kind of name is found, with nothing listed by hand", {
  skip_if_no_pandoc()
  old <- options(easypaper.species_offline = TRUE)
  on.exit(options(old), add = TRUE)
  cache <- copy_cache()
  out <- tempfile(fileext = ".json")
  on.exit(unlink(c(out, cache)), add = TRUE)
  res <- italicize_species(fx("cases.bib"), out, cache = cache, quiet = TRUE)
  expect_false(attr(res, "offline"))
  t <- titles_of(out)

  expected <- list(
    binomial        = "Pinus halepensis",
    subspecies      = c("Quercus ilex", "ballota", "Q. suber"),  # subsp. in roman
    abbreviation    = c("Q. ruber", "Quercus"),                  # Quercus spp.
    unlisted        = c("Quercus ruber", "Q. rubra"),  # not in GBIF as a pair
    genus           = "Wolbachia",                     # Peru and Chile are genera too
    places          = "Escherichia coli",              # the Andes are a genus too
    none            = character(0),
    spanish         = c("Fagus sylvatica", "Abies alba"),
    genuscue        = "Candida",                       # "the Genus Candida"
    speciescue      = "Oenanthe",                      # "Oenanthe Species"
    latex           = "Drosophila melanogaster",       # \textit{} in the .bib
    commonsentence  = "Gorilla",                       # "diet of Gorilla"
    commonbird      = c("Haemoproteus trarotraro", "Caracara plancus"),
    diacritics      = c("Kalanchoë daigremontiana", "Agrobacterium tumefaciens"),
    capitalepithet  = "Helicobacter pylori",           # "Pylori" lowercased
    trinomial       = "Epilachna sparsa orientalis",
    highertaxon     = "Encephalitozoon cuniculi",      # (Microspora) stays roman
    notepithet      = "Tribolium",                     # "sibling" is no epithet
    commonnoun      = "Vicia faba",                    # "faba bean" is the crop
    commontitlecase = character(0),
    markeditalic    = "Gorilla",
    markedroman     = character(0),
    ambiguous       = character(0),
    unverified      = "Paramecium"
  )
  for (id in names(expected)) {
    expect_identical(italics(t[[id]]), expected[[id]], info = id)
  }
})

test_that("titles keep their capitals, and names keep theirs in any style", {
  skip_if_no_pandoc()
  old <- options(easypaper.species_offline = TRUE)
  on.exit(options(old), add = TRUE)
  cache <- copy_cache()
  out <- tempfile(fileext = ".json")
  on.exit(unlink(c(out, cache)), add = TRUE)

  # By default: exactly as written, the whole title protected from the style,
  # and the name marked so that no style can lowercase or capitalise it.
  italicize_species(fx("cases.bib"), out, cache = cache, quiet = TRUE)
  t <- titles_of(out)$binomial
  expect_match(t, '^<span class="nocase">Effects of Fire on ')
  expect_match(t, '<i><span class="nocase">Pinus halepensis</span></i>', fixed = TRUE)
  expect_match(t, "Eastern Spain", fixed = TRUE)

  # keep_case = FALSE: pandoc lowercases the English title, as it always has;
  # the name keeps its capital all the same, and so does what is protected.
  italicize_species(fx("cases.bib"), out, cache = cache, quiet = TRUE,
                    keep_case = FALSE, protect = "Spain")
  t <- titles_of(out)$binomial
  expect_match(t, "^Effects of fire on ")
  expect_match(t, '<i><span class="nocase">Pinus halepensis</span></i>', fixed = TRUE)
  expect_match(t, '<span class="nocase">Spain</span>', fixed = TRUE)
})

test_that("a doubtful case is reported with where it is and what to write", {
  skip_if_no_pandoc()
  old <- options(easypaper.species_offline = TRUE)
  on.exit(options(old), add = TRUE)
  cache <- copy_cache()
  out <- tempfile(fileext = ".json")
  on.exit(unlink(c(out, cache)), add = TRUE)
  said <- paste(utils::capture.output(
    res <- italicize_species(fx("cases.bib"), out, cache = cache),
    type = "message"), collapse = "\n")

  d <- attr(res, "doubtful")
  expect_setequal(paste(d$id, d$word),
                  c("genuscue Eucalyptus", "commontitlecase Gorilla",
                    "commonbird Caracara", "ambiguous Iris", "ambiguous Victoria",
                    "unverified Paramecium primaurelia"))
  # The line is the one the word is on, in the file you edit.
  bib <- readLines(fx("cases.bib"), warn = FALSE)
  for (k in seq_len(nrow(d))) {
    expect_match(bib[d$line[k]], d$word[k], fixed = TRUE, info = d$word[k])
  }
  expect_match(said, "6 doubtful cases", fixed = TRUE)
  expect_match(said, "change Eucalyptus to  \\textit{Eucalyptus}", fixed = TRUE)
  expect_match(said, "change Eucalyptus to  \\textup{Eucalyptus}", fixed = TRUE)
  # For a binomial GBIF does not list, what is in doubt is the epithet.
  expect_match(said, "change primaurelia to  \\textup{primaurelia}", fixed = TRUE)

  # A word marked by hand, either way, is settled: it is not reported.
  expect_false(any(d$id %in% c("markeditalic", "markedroman")))
  # And a journal named after a genus (Oryx) is not a title to read.
  expect_false("Oryx" %in% d$word)
})

test_that("CSL-JSON goes in and comes out, marks included", {
  # No pandoc and no lookup: a CSL-JSON is read directly, and with gbif = FALSE
  # only the names given are set in italics.
  refs <- tempfile(fileext = ".json")
  out <- tempfile(fileext = ".json")
  on.exit(unlink(c(refs, out)), add = TRUE)
  writeLines(c(
    '[{"id": "a", "type": "article-journal", "container-title": "Oryx",',
    '  "title": "Diet of Gorilla gorilla and <i>Pan troglodytes</i> in Gabon"},',
    ' {"id": "b", "type": "article-journal",',
    '  "title": "<span style=\\"font-style:normal;\\">Gorilla</span> tourism in Uganda"}]'),
    refs)
  res <- italicize_species(refs, out, names = c("Gorilla gorilla", "Pan troglodytes"),
                           gbif = FALSE, quiet = TRUE)
  items <- jsonlite::read_json(out)
  expect_identical(italics(items[[1]]$title), c("Gorilla gorilla", "Pan troglodytes"))
  # The italics the file already had are replaced by protected ones.
  expect_match(items[[1]]$title, '<i><span class="nocase">Pan troglodytes</span></i>',
               fixed = TRUE)
  # Marked roman by hand: left in roman although Gorilla is a known genus.
  expect_identical(italics(items[[2]]$title), character(0))
  # The journal is left exactly as it was.
  expect_identical(items[[1]][["container-title"]], "Oryx")
  expect_setequal(attr(res, "italicized"), c("Gorilla gorilla", "Pan troglodytes"))
})

test_that("without a connection nothing fails, and it says so", {
  skip_if_no_pandoc()
  old <- options(easypaper.species_offline = TRUE)
  on.exit(options(old), add = TRUE)
  cache <- tempfile(fileext = ".rds")   # empty: nothing has been looked up
  out <- tempfile(fileext = ".json")
  on.exit(unlink(c(cache, out)), add = TRUE)

  expect_warning(
    res <- italicize_species(fx("cases.bib"), out, cache = cache, quiet = TRUE),
    "No connection")
  expect_true(attr(res, "offline"))
  expect_true(file.exists(out))
  expect_identical(italics(titles_of(out)$binomial), character(0))
  # What could not be asked is not stored as an answer: online, it is asked.
  expect_false(file.exists(cache))
})

test_that("300 real references come out as they did", {
  # realworld.bib: 300 titles drawn at random from Crossref among those whose
  # publisher marked the italics. The exact output is pinned, so any change
  # shows here; accept an intended one by rerunning dev/species_fixtures.R.
  skip_if_no_pandoc()
  old <- options(easypaper.species_offline = TRUE)
  on.exit(options(old), add = TRUE)
  cache <- copy_cache()
  out <- tempfile(fileext = ".json")
  on.exit(unlink(c(out, cache)), add = TRUE)
  res <- italicize_species(fx("realworld.bib"), out, cache = cache, quiet = TRUE)
  expect_false(attr(res, "offline"))

  got <- titles_of(out)
  pinned <- jsonlite::read_json(fx("realworld_expected.json"))
  expect_identical(names(got), names(pinned))
  for (id in names(pinned)) expect_identical(got[[id]], pinned[[id]], info = id)

  # And against the publishers: word by word, the italics agree on 241 of the
  # 300 at 0.4.0. Of the other 59, 49 differ only in italics that are no genus
  # or species -- journal titles, viruses, genes, Latin phrases -- 4 are
  # reported as doubtful, 2 are the publisher's typos, 1 is the publisher
  # setting names in roman inside an italic title, and 3 are errors of this
  # function.
  pub <- jsonlite::read_json(fx("publisher.json"))
  words <- function(s) {
    s <- gsub("&amp;", "&", gsub("</?span[^>]*>", "", s), fixed = TRUE)
    parts <- regmatches(s, gregexpr("</?i>|[^<]+|<", s))[[1]]
    it <- cumsum(parts == "<i>") > cumsum(parts == "</i>")
    unlist(Map(function(p, i) {
      w <- regmatches(p, gregexpr("[[:alnum:]]+", p))[[1]]
      if (length(w)) paste0(if (i) "*", tolower(w))
    }, parts[!parts %in% c("<i>", "</i>")], it[!parts %in% c("<i>", "</i>")]),
    use.names = FALSE)
  }
  same <- vapply(names(pub), function(id) identical(words(pub[[id]]), words(got[[id]])),
                 logical(1))
  expect_gte(sum(same), 241L)
})

test_that("the default cache lives where CRAN allows a package to write", {
  # Compared whole, not through dirname(): on Windows dirname() rewrites the
  # separators to "/", and R_user_dir() keeps the "\\" of LOCALAPPDATA.
  expect_identical(
    easypaper:::.sp_default_cache(),
    file.path(tools::R_user_dir("easypaper", "cache"), "species_cache.rds"))
})
