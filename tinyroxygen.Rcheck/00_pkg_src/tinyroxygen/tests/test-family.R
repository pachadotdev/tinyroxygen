library(tinyroxygen)
source("helper/pkg.R")

# @family adds an "Other <name>: ..." block to \seealso{}, linking every
# other topic that shares the same family name
pkgdir <- make_test_pkg(a.R = c(
  "#' A",
  "#' @family math",
  "a <- function() {}",
  "",
  "#' B",
  "#' @family math",
  "b <- function() {}"
))
roxygenise(pkgdir)

rd_a <- read_rd(pkgdir, "a")
stopifnot(identical(rd_section(rd_a, "seealso"), "Other math: \\code{\\link{b}}"))

rd_b <- read_rd(pkgdir, "b")
stopifnot(identical(rd_section(rd_b, "seealso"), "Other math: \\code{\\link{a}}"))

# @family combines with an explicit @seealso tag on the same topic instead
# of replacing it
pkgdir <- make_test_pkg(a.R = c(
  "#' A",
  "#' @seealso some other resource",
  "#' @family math",
  "a <- function() {}",
  "",
  "#' B",
  "#' @family math",
  "b <- function() {}"
))
roxygenise(pkgdir)
rd_a <- read_rd(pkgdir, "a")
stopifnot(identical(rd_section(rd_a, "seealso"), c(
  "some other resource",
  "",
  "Other math: \\code{\\link{b}}"
)))

# a topic with no siblings in its family produces no \seealso{} block at
# all (no explicit @seealso tag either)
pkgdir <- make_test_pkg(a.R = c(
  "#' A",
  "#' @family math",
  "a <- function() {}"
))
roxygenise(pkgdir)
rd_a <- read_rd(pkgdir, "a")
stopifnot(is.null(rd_section(rd_a, "seealso")))

cat("family test passed\n")
