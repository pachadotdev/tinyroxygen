library(tinyroxygen)
source("helper/pkg.R")

# single paragraph -> description falls back to title
pkgdir <- make_test_pkg(a.R = c(
  "#' title",
  "#' @name a",
  "NULL"
))
roxygenise(pkgdir)
rd <- read_rd(pkgdir, "a")
stopifnot(any(grepl("^\\\\title\\{title\\}$", rd)))
stopifnot(identical(rd_section(rd, "description"), "title"))

# title / description / details from 3 paragraphs
pkgdir <- make_test_pkg(a.R = c(
  "#' title",
  "#'",
  "#' description",
  "#'",
  "#' details",
  "#' @name a",
  "NULL"
))
roxygenise(pkgdir)
rd <- read_rd(pkgdir, "a")
stopifnot(any(grepl("^\\\\title\\{title\\}$", rd)))
stopifnot(identical(rd_section(rd, "description"), "description"))
stopifnot(identical(rd_section(rd, "details"), "details"))

# @title overrides default title (description falls back to the final
# title too - tinyroxygen doesn't keep the original first paragraph
# around once @title overrides it, unlike roxygen2)
pkgdir <- make_test_pkg(a.R = c(
  "#' Would be title",
  "#' @title Overridden title",
  "#' @name a",
  "NULL"
))
roxygenise(pkgdir)
rd <- read_rd(pkgdir, "a")
stopifnot(any(grepl("^\\\\title\\{Overridden title\\}$", rd)))
stopifnot(identical(rd_section(rd, "description"), "Overridden title"))

# @title/@description tags work with no intro text at all
pkgdir <- make_test_pkg(a.R = c(
  "#' @title My title",
  "#' @description My description",
  "#' @param x value",
  "a <- function(x) {}"
))
roxygenise(pkgdir)
rd <- read_rd(pkgdir, "a")
stopifnot(any(grepl("^\\\\title\\{My title\\}$", rd)))
stopifnot(identical(rd_section(rd, "description"), "My description"))

cat("title/description test passed\n")
