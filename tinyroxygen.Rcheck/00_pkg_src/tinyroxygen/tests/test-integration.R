# Base R only, no testthat/tinytest: R CMD check runs every *.R file in
# tests/ as a script and treats any error() as a failure. This mirrors
# tinyroxygen's own "no extra framework needed" philosophy.

library(tinyroxygen)

pkgdir <- tempfile("tinyroxygenpkg")
dir.create(file.path(pkgdir, "R"), recursive = TRUE)

writeLines(
  c(
    "Package: examplepkg",
    "Version: 0.1",
    "License: MIT"
  ),
  file.path(pkgdir, "DESCRIPTION")
)

writeLines(
  c(
    "#' Add together two numbers",
    "#'",
    "#' @param x A number.",
    "#' @param y A number.",
    "#' @returns A number.",
    "#' @export",
    "#' @examples",
    "#' add(1, 1)",
    "add <- function(x, y) {",
    "  x + y",
    "}",
    "",
    "#' Internal helper",
    "#'",
    "#' @noRd",
    "helper <- function() invisible(NULL)"
  ),
  file.path(pkgdir, "R", "add.R")
)

roxygenise(pkgdir)

rd_path <- file.path(pkgdir, "man", "add.Rd")
stopifnot(file.exists(rd_path))
rd <- readLines(rd_path)
stopifnot(any(grepl("\\\\name\\{add\\}", rd)))
stopifnot(any(grepl("\\\\alias\\{add\\}", rd)))
stopifnot(any(grepl("^add\\(x, y\\)$", rd)))
stopifnot(any(grepl("\\\\item\\{x\\}\\{A number\\.\\}", rd)))
stopifnot(any(grepl("A number\\.", rd)))

stopifnot(!file.exists(file.path(pkgdir, "man", "helper.Rd")))

ns <- readLines(file.path(pkgdir, "NAMESPACE"))
stopifnot(any(grepl("^export\\(add\\)$", ns)))
stopifnot(!any(grepl("helper", ns)))

cat("integration test passed\n")
