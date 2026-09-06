# ===========================================================================
# run.R -- the commands, ready to run.
#
# Nothing in this project calls this file: it is a cheat sheet. Open it, put
# the cursor on the line you want and press Cmd+Enter (Ctrl+Enter on Windows).
# The point is that you never have to remember a function name or an argument.
#
# Do NOT source() it: that would fire every render, one after another. The
# guard below stops you if you try.
#
# The actual code lives in make.R, R/submission.R and R/crossref_styles.R.
#
# What each argument does, in tables and with its default, is in the Get
# started guide: https://danielsangarci.github.io/easypaper/articles/easypaper.html
# ===========================================================================

if (sys.nframe() > 0L) {
  stop("run.R is a cheat sheet: run its lines one at a time, do not source() it.",
       call. = FALSE)
}


# --- 0. ALWAYS FIRST -------------------------------------------------------
# Loads every function below. Repeat it after each restart of R (if you get
# 'could not find function', this is what you forgot).

source("make.R")


# --- 1. WHILE WRITING ------------------------------------------------------
# Fast feedback. Not what you send to anyone.

render_html()          # .html in output/, seconds instead of minutes
preview()              # live preview: re-renders on every save. Esc to stop
list_journals()        # which .csl you have in references_styles/


# --- 2. FULL RENDERS -------------------------------------------------------
# journal       = name of a .csl, without the extension (list_journals())
# caption_style = "default" | "abbrev" | "nature" | "compact"
# split         = TRUE leaves the supplement out and gives each document its
#                 own bibliography; FALSE is the whole thing in one file

render_journal("myrmecological-news")               # -> output/journal/*.docx
render_journal("ecology-letters", "abbrev")        # another journal, "Fig. 1."
render_preprint("myrmecological-news")              # -> output/preprint/*.pdf
render_supplementary("myrmecological-news")         # the supplement(s) on their
                                                   # own: one document per
                                                   # _sections/8*suppl*.qmd
render_html("myrmecological-news", "nature")        # "Figure 1 | caption"

make_all()                                         # docx + pdf + supplement
make_all("ecology-letters", "abbrev")              # the same, another journal


# --- 3. SUBMISSION ---------------------------------------------------------
# label         = name of the folder inside submission/ and the suffix of every
#                 file in it. Defaults to "default" so a trial run cannot be
#                 mistaken for a real submission
# figure_format = "tiff" (what journals ask for) | "png" | "jpg"
# blinded       = TRUE splits it for double-blind review: title_*.docx from the
#                 title to just before the Abstract, main_*.docx from the
#                 Abstract on, with no author anywhere

# suppl_figures = "separate" leaves the supplementary figures and tables in
#                 their own document, and rewrites @sfig-map in the main text
#                 to the plain "Figure S1"
#                 "main" keeps them at the end of main_*.docx instead.
#                 Supplementary TEXT (an extended Methods) always goes out on
#                 its own, with its own reference list -- see the README

make_submission()                                  # trial -> submission/default/
make_submission("myrmecological-news", suppl_figures = "main")
                                                   # ^ floats in the main text
make_submission("myrmecological-news", label = "MyrmecologicalNews")
                                                   # ^ the real submission
make_submission("myrmecological-news", label = "MyrmecologicalNews", snapshot = FALSE)
                                                   # ^ do NOT touch renv.lock
make_submission("ecology-letters", label = "EcologyLetters",
                figure_format = "png", blinded = FALSE)


# --- 4. CHECKS -------------------------------------------------------------
# The three renders run these on their own. Call them when you want to know
# before waiting for a render.

check_citations()      # @keys with no entry in references/, and vice versa
check_crossrefs()      # @fig-/@tbl- with no target, and figures nobody cites
check_title()          # does title_page.qmd still match the manuscript?
export_figure_formats()# figures/png/ -> figures/jpg/ and figures/tiff/ at 600 dpi
check_renv()           # is renv.lock there, and does it match what you are using?


# --- 5. MAINTENANCE --------------------------------------------------------

renv::snapshot()       # record the packages in renv.lock by hand. Renders
                       # never touch it; make_submission() does, on purpose
clean_cache()          # after touching data/: knitr does NOT notice by itself
sync_licenses()        # copies the authors from the YAML into LICENSE*/README
export_code()          # analysis_code.R + sessionInfo.txt for the supplement


# --- 6. CO-AUTHORS IN GOOGLE DOCS (trackdown) ------------------------------
# Needs the GitHub version: remotes::install_github("claudiozandonella/trackdown")
# section = the file name in _sections/, with or without the extension

td_upload("2_introduction")     # first upload
td_update("2_introduction")     # overwrite with your local version
td_download("2_introduction")   # bring back their edits BEFORE editing locally


# --- 7. FIRST TIME ONLY ----------------------------------------------------
# renv::init()                  # OPTIONAL: renv's isolated project library.
#                               # Not needed for the lockfile: make_submission()
#                               # writes renv.lock from the library you use
# source("R/create_metadata.R") # dataspice metadata, filled in by hand
# source("R/xlsx_to_csv.R")     # then xlsx_to_csv("file.xlsx", sheet = 1)
