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

# A bare @export on a method belonging to a UseMethod() generic registers
# the method without exporting the dotted implementation or documenting it
# as a separate topic.
pkgdir <- make_test_pkg(a.R = c(
  "#' A generic function",
  "#'",
  "#' This is a generic function.",
  "#'",
  "#' @param x An input.",
  "#' @returns An output.",
  "#' @export",
  "my_func <- function(x) {",
  "  UseMethod(\"my_func\")",
  "}",
  "",
  "#' @export",
  "my_func.default <- function(x) x"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("export(my_func)" %in% ns)
stopifnot("S3method(my_func, default)" %in% ns)
stopifnot(!("export(my_func.default)" %in% ns))
stopifnot(file.exists(file.path(pkgdir, "man", "my_func.Rd")))
stopifnot(!file.exists(file.path(pkgdir, "man", "my_func.default.Rd")))

# @import / @importFrom
pkgdir <- make_test_pkg(a.R = c(
  "#' @title Function A",
  "#' @import stats",
  "#' @importFrom utils head tail",
  "a <- function() {}"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("import(stats)" %in% ns)
stopifnot("importFrom(utils,head)" %in% ns)
stopifnot("importFrom(utils,tail)" %in% ns)

cat("namespace S3method/import test passed\n")
