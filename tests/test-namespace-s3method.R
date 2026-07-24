library(tinyroxygen)
source("helper/pkg.R")

# @exportS3Method with no value: generic/class inferred from name.class
pkgdir <- make_test_pkg(a.R = c(
  "#' @exportS3Method",
  "mean.foo <- function(x) \"foo\""
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("S3method(mean, foo)" %in% ns)

# @exportS3Method generic class: explicit literal directive
pkgdir <- make_test_pkg(a.R = c(
  "#' @exportS3Method print foo",
  "some_function <- function(x) \"foo\""
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("S3method(print, foo)" %in% ns)

# @import / @importFrom
pkgdir <- make_test_pkg(a.R = c(
  "#' @import stats",
  "#' @importFrom utils head tail",
  "a <- function() {}"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("import(stats)" %in% ns)
stopifnot("importFrom(utils,head,tail)" %in% ns)

cat("namespace S3method/import test passed\n")
