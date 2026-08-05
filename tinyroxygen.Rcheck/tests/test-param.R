library(tinyroxygen)
source("helper/pkg.R")

# @param documents arguments, in declaration order
pkgdir <- make_test_pkg(a.R = c(
  "#' A",
  "#' @param a first",
  "#' @param z last",
  "a <- function(a = 1, z = 2) {}"
))
roxygenise(pkgdir)
rd <- read_rd(pkgdir, "a")
args <- rd_section(rd, "arguments")
stopifnot(identical(args, c(
  "\\item{a}{first}", "",
  "\\item{z}{last}"
)))

# grouped @param a,z gets one \item per name, same description
pkgdir <- make_test_pkg(a.R = c(
  "#' A",
  "#' @param a,z Two arguments",
  "a <- function(a = 1, z = 2) {}"
))
roxygenise(pkgdir)
rd <- read_rd(pkgdir, "a")
args <- rd_section(rd, "arguments")
stopifnot(identical(args, c(
  "\\item{a}{Two arguments}", "",
  "\\item{z}{Two arguments}"
)))

# tinyroxygen does NOT reorder @param entries to match the function's
# formal argument order (unlike roxygen2) - they appear in @param
# declaration order
pkgdir <- make_test_pkg(a.R = c(
  "#' A",
  "#' @param y Y",
  "#' @param x X",
  "a <- function(x, y) {}"
))
roxygenise(pkgdir)
rd <- read_rd(pkgdir, "a")
args <- rd_section(rd, "arguments")
stopifnot(identical(args, c(
  "\\item{y}{Y}", "",
  "\\item{x}{X}"
)))

# non-function objects don't get a \usage{} section
pkgdir <- make_test_pkg(a.R = c(
  "#' A string",
  "#' @name greeting",
  "x <- \"hello\""
))
roxygenise(pkgdir)
rd <- read_rd(pkgdir, "greeting")
stopifnot(is.null(rd_section(rd, "usage")))

# @inheritParams fills in params not already documented locally, appended
# after the local ones, in the source's own @param declaration order
pkgdir <- make_test_pkg(a.R = c(
  "#' A",
  "#' @param x the x value",
  "#' @param y the y value",
  "a <- function(x, y) {}",
  "",
  "#' B",
  "#' @param z the z value",
  "#' @inheritParams a",
  "b <- function(x, y, z) {}"
))
roxygenise(pkgdir)
rd <- read_rd(pkgdir, "b")
args <- rd_section(rd, "arguments")
stopifnot(identical(args, c(
  "\\item{z}{the z value}", "",
  "\\item{x}{the x value}", "",
  "\\item{y}{the y value}"
)))

# a local @param always wins over an inherited one with the same name
pkgdir <- make_test_pkg(a.R = c(
  "#' A",
  "#' @param x the x value",
  "a <- function(x) {}",
  "",
  "#' B",
  "#' @param x local override",
  "#' @inheritParams a",
  "b <- function(x) {}"
))
roxygenise(pkgdir)
rd <- read_rd(pkgdir, "b")
args <- rd_section(rd, "arguments")
stopifnot(identical(args, c("\\item{x}{local override}")))

cat("param test passed\n")
