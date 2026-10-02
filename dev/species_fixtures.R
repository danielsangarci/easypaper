# Regenerates the fixtures of tests/testthat/test-italicize_species.R.
#
# The tests run offline: every question italicize_species() asks GBIF and
# Wikipedia about the two bibliographies below is answered from cache.rds,
# and the option easypaper.species_offline makes any question that is not
# fail instead of reaching the network. So whenever the function starts asking
# something new -- a new rule, a new kind of lookup -- run this, with a
# connection, and commit what it rewrites:
#
#   cache.rds               every answer the two bibliographies need
#   realworld_expected.json what the function makes of realworld.bib today;
#                           the test fails on any difference, so an
#                           intentional change is accepted by rerunning this
#
# realworld.bib is 300 titles drawn at random from Crossref -- PeerJ, Wiley,
# Taylor & Francis and bioRxiv -- among those whose publisher marked the
# italics, and publisher.json the same titles with the publisher's italics.
# They were drawn once and are not redrawn here.

devtools::load_all()
fx <- file.path("tests", "testthat", "fixtures", "italicize_species")
cache <- file.path(fx, "cache.rds")

for (f in c("cases.bib", "realworld.bib")) {
  italicize_species(file.path(fx, f), tempfile(fileext = ".json"),
                    cache = cache, quiet = TRUE)
}

# Every answer must now be in the cache: a second pass, offline, proves it.
op <- options(easypaper.species_offline = TRUE)
out <- italicize_species(file.path(fx, "realworld.bib"),
                         tempfile(fileext = ".json"), cache = cache, quiet = TRUE)
chk <- italicize_species(file.path(fx, "cases.bib"),
                         tempfile(fileext = ".json"), cache = cache, quiet = TRUE)
options(op)
stopifnot(!attr(out, "offline"), !attr(chk, "offline"))

items <- jsonlite::read_json(out)
expected <- stats::setNames(lapply(items, function(x) x$title),
                            vapply(items, function(x) x$id, ""))
jsonlite::write_json(expected, file.path(fx, "realworld_expected.json"),
                     auto_unbox = TRUE, pretty = TRUE)
