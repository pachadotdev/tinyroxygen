library(tinyroxygen)
source("helper/pkg.R")

# basic @export
pkgdir <- make_test_pkg(a.R = c(
  "#' @export",
  "a <- function() {}"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("export(a)" %in% ns)

# @export <name> overrides the default (the object's own name)
pkgdir <- make_test_pkg(a.R = c(
  "#' @export b",
  "a <- function() {}"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("export(b)" %in% ns)
stopifnot(!("export(a)" %in% ns))

# @export a b generates multiple exports
pkgdir <- make_test_pkg(a.R = c(
  "#' @export a b",
  "a <- function() {}"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("export(a)" %in% ns)
stopifnot("export(b)" %in% ns)

# a blank #' line right after @export doesn't break the association
pkgdir <- make_test_pkg(a.R = c(
  "#' @export",
  "#'",
  "a <- function() {}"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("export(a)" %in% ns)

# tinyroxygen does NOT special-case setClass()/setGeneric() the way
# roxygen2 does: @export on a bare setClass() call just does export(name),
# not exportClasses(name). Use the explicit @exportClass tag for that.
pkgdir <- make_test_pkg(a.R = c(
  "#' @export",
  "setClass(\"a\")"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("export(a)" %in% ns)
stopifnot(!any(grepl("exportClasses", ns)))

pkgdir <- make_test_pkg(a.R = c(
  "#' @exportClass",
  "setClass(\"a\")"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("exportClasses(a)" %in% ns)

cat("namespace export test passed\n")
