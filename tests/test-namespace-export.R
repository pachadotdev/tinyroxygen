library(tinyroxygen)
source("helper/pkg.R")

# basic @export
pkgdir <- make_test_pkg(a.R = c(
  "#' @title Function A",
  "#' @export",
  "a <- function() {}"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("export(a)" %in% ns)

# @export <name> overrides the default (the object's own name)
pkgdir <- make_test_pkg(a.R = c(
  "#' @title Function A",
  "#' @export b",
  "a <- function() {}"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("export(b)" %in% ns)
stopifnot(!("export(a)" %in% ns))

# @export a b generates multiple exports
pkgdir <- make_test_pkg(a.R = c(
  "#' @title Function A",
  "#' @export a b",
  "a <- function() {}"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("export(a)" %in% ns)
stopifnot("export(b)" %in% ns)

# a blank #' line right after @export doesn't break the association
pkgdir <- make_test_pkg(a.R = c(
  "#' @title Function A",
  "#' @export",
  "#'",
  "a <- function() {}"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("export(a)" %in% ns)

# replacement-function names must be exported and aliased without
# becoming invalid NAMESPACE/Rd code
pkgdir <- make_test_pkg(a.R = c(
  "#' @title Var Label",
  "#' @name varlabel",
  "#' @rdname varlabel",
  "#' @export \"varlabel<-\"",
  "\"varlabel<-\" <- function(dat, value) { dat }"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("export(\"varlabel<-\")" %in% ns)
rd <- read_rd(pkgdir, "varlabel")
stopifnot(any(grepl("\\alias{varlabel<-}", rd, fixed = TRUE)))
stopifnot(any(grepl('"varlabel<-"(dat, value)', rd, fixed = TRUE)))

# tinyroxygen does NOT special-case setClass()/setGeneric() the way
# roxygen2 does: @export on a bare setClass() call just does export(name),
# not exportClasses(name). Use the explicit @exportClass tag for that.
pkgdir <- make_test_pkg(a.R = c(
  "#' @title Letter A",
  "#' @export",
  "setClass(\"a\")"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("export(a)" %in% ns)
stopifnot(!any(grepl("exportClasses", ns)))

pkgdir <- make_test_pkg(a.R = c(
  "#' @title Letter A",
  "#' @exportClass",
  "setClass(\"a\")"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("exportClasses(a)" %in% ns)

# @importFrom with several names writes one importFrom() directive per
# name, rather than combining them into a single call. Combining them is
# broken for non-syntactic names (e.g. `:=`, `%>%`): R's namespace loader
# extracts import names via as.character() on the whole call, which
# re-quotes non-syntactic symbols with backticks when there's more than
# one element - unlike as.character() on a lone symbol, which strips them
# - so a combined directive ends up looking up the literal string
# "`:=`" instead of ":=" and fails to load. See roclet-namespace.R.
pkgdir <- make_test_pkg(a.R = c(
  "#' @title Function A",
  "#' @importFrom data.table `:=` copy",
  "a <- function() {}"
))
roxygenise(pkgdir)
ns <- read_ns(pkgdir)
stopifnot("importFrom(data.table,`:=`)" %in% ns)
stopifnot("importFrom(data.table,copy)" %in% ns)
stopifnot(!any(grepl("^importFrom\\(data\\.table,.*,.*\\)$", ns)))

cat("namespace export test passed\n")
