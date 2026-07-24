#' tinyroxygen: a tiny 'roxygen'-style documentation generator
#'
#' @description Reads '#'' comment blocks above R functions and objects and
#'   turns them into '.Rd' documentation files and a 'NAMESPACE' file, using
#'   base R only. It is a minimal, non-magical alternative to 'roxygen2' for
#'   situations where installing 'roxygen2' and its dependencies is
#'   impractical (e.g. slow or restricted institutional servers).
#' @keywords internal
#' @useDynLib tinyroxygen, .registration = TRUE
"_PACKAGE"

#' Generate documentation from roxygen comments
#'
#' @description Parses the '#'' comment blocks in the 'R/' directory of a
#'   package, writes the corresponding '.Rd' files to 'man/', and writes a
#'   'NAMESPACE' file based on '@export' and related tags.
#' @param pkgdir Path to the package directory. Defaults to the current
#'   directory.
#' @return Invisibly returns the package directory.
#' @export
#' @examples
#' \dontrun{
#' roxygenise("path/to/package")
#' }
roxygenise <- function(pkgdir = ".") {
  pkgdir <- normalizePath(pkgdir, winslash = "/", mustWork = TRUE)
  if (!file.exists(file.path(pkgdir, "DESCRIPTION"))) {
    die("%s does not look like an R package (no DESCRIPTION file)", pkgdir)
  }

  blocks <- collect_blocks(pkgdir)
  topics <- group_blocks_by_topic(blocks)
  param_index <- build_param_index(blocks)
  family_index <- build_family_index(topics)

  rd_roclet_write(pkgdir, topics, param_index, family_index)
  ns <- namespace_roclet_build(blocks)
  namespace_roclet_write(pkgdir, ns)

  invisible(pkgdir)
}

#' @rdname roxygenise
#' @export
roxygenize <- roxygenise
