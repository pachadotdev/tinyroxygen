# Internal: turn a DESCRIPTION "Imports"/"Suggests" field value (as returned
# by read.dcf(..., all = TRUE), i.e. one string with embedded newlines) into
# a named list of pkg -> "(>= 1.0.0)" version-pin strings ("" if unpinned).
parse_dcf_deps <- function(field) {
  if (is.null(field) || is.na(field) || !nzchar(field)) {
    return(list())
  }
  entries <- strsplit(field, ",")[[1]]
  entries <- str_trim(gsub("\\s+", " ", entries))
  entries <- entries[nzchar(entries)]

  out <- list()
  for (entry in entries) {
    m <- regmatches(entry, regexec("^([a-zA-Z][a-zA-Z0-9._]*)\\s*(\\(.*\\))?$", entry))[[1]]
    if (length(m) == 0L) {
      next
    }
    out[[m[2]]] <- if (nzchar(m[3])) m[3] else ""
  }
  out
}

#' @title Update DESCRIPTION Imports and Suggests fields
#' @description Scan R code in the package directories to identify used
#'   packages and update the 'Imports' and 'Suggests' fields in the
#'   'DESCRIPTION' file. Packages found in 'dir.r' go to 'Imports'; packages
#'   found only in 'dir.v' or 'dir.t' go to 'Suggests'. Detects
#'   'pkg::fun()', '@importFrom pkg fun', 'library(pkg)', and 'require(pkg)'
#'   patterns. Uses only 'read.dcf'/'write.dcf' from base R, so it does not
#'   require installing the 'desc' package or any of its dependencies.
#' @param pkgdir The path to the package directory. Defaults to the current
#'   directory.
#' @param dir.r Directory with R scripts (Imports). Defaults to 'R'.
#' @param dir.v Vignettes directory (Suggests). Set to '' to skip.
#' @param dir.t Tests directory (Suggests). Set to '' to skip.
#' @param extra_suggests Character vector of extra packages to add to
#'   Suggests.
#' @param pkg_ignore Character vector of package names to exclude from both
#'   fields.
#' @return Invisibly returns the path to the 'DESCRIPTION' file.
#' @export
description_update <- function(
  pkgdir = ".",
  dir.r = "R",
  dir.v = "vignettes",
  dir.t = "tests",
  extra_suggests = NULL,
  pkg_ignore = NULL
) {
  pkg <- normalizePath(pkgdir, winslash = "/", mustWork = TRUE)
  desc_file <- file.path(pkg, "DESCRIPTION")
  if (!file.exists(desc_file)) {
    die("%s does not look like an R package (no DESCRIPTION file)", pkg)
  }

  base_pkgs <- c(
    "base", "compiler", "datasets", "graphics", "grDevices",
    "grid", "methods", "parallel", "splines", "stats", "stats4",
    "tcltk", "tools", "utils"
  )

  pkgname <- pkg_name(pkg)

  scan_pkgs <- function(dirs) {
    file_pat <- "\\.[Rr]$|\\.[Rr]md$|\\.qmd$"
    files <- unlist(lapply(dirs, function(d) {
      d_full <- file.path(pkg, d)
      if (!nzchar(d) || !dir.exists(d_full)) {
        return(character())
      }
      list.files(d_full, pattern = file_pat, full.names = TRUE, recursive = TRUE)
    }))
    if (length(files) == 0L) {
      return(character())
    }

    lines <- unlist(lapply(files, readLines, warn = FALSE))

    # @importFrom pkg — roxygen comment lines only. Only match @importFrom
    # when it is an actual roxygen tag (at the start of the comment
    # content), not when the text appears inside prose or quoted examples.
    roxy_tags <- lines[grepl("^\\s*#'\\s*@importFrom\\s", lines)]
    import_from <- character()
    if (length(roxy_tags) > 0L) {
      m <- gregexpr("(?<=@importFrom\\s)[a-zA-Z][a-zA-Z0-9.]*", roxy_tags, perl = TRUE)
      import_from <- unique(unlist(regmatches(roxy_tags, m)))
    }

    # strip all comments before extracting code patterns
    code <- gsub("#.*$", "", lines)

    # pkg::fun
    m2 <- gregexpr("[a-zA-Z][a-zA-Z0-9.]*(?=::)", code, perl = TRUE)
    ns_pkgs <- unique(unlist(regmatches(code, m2)))

    # library(pkg) / library("pkg") / library('pkg')
    lib_m <- gregexpr(
      "(?<=\\blibrary\\()[\"']?([a-zA-Z][a-zA-Z0-9.]*)[\"']?(?=\\s*[,)])",
      code, perl = TRUE
    )
    lib_pkgs <- gsub("[\"']", "", unique(unlist(regmatches(code, lib_m))))

    # require(pkg) / require("pkg") / require('pkg')
    req_m <- gregexpr(
      "(?<=\\brequire\\()[\"']?([a-zA-Z][a-zA-Z0-9.]*)[\"']?(?=\\s*[,)])",
      code, perl = TRUE
    )
    req_pkgs <- gsub("[\"']", "", unique(unlist(regmatches(code, req_m))))

    unique(c(ns_pkgs, import_from, lib_pkgs, req_pkgs))
  }

  imports_raw <- scan_pkgs(dir.r)
  suggests_raw <- scan_pkgs(c(dir.v, dir.t))

  filter_pkgs <- function(pkgs, exclude = character()) {
    pkgs <- pkgs[nzchar(pkgs)]
    pkgs <- pkgs[!pkgs %in% base_pkgs]
    pkgs <- pkgs[!pkgs %in% pkg_ignore]
    pkgs <- pkgs[pkgs != pkgname]
    pkgs <- pkgs[!pkgs %in% exclude]
    sort(unique(pkgs))
  }

  imports <- filter_pkgs(imports_raw)
  suggests <- filter_pkgs(suggests_raw, exclude = imports)

  if (!is.null(extra_suggests)) {
    suggests <- sort(unique(c(suggests, extra_suggests[!extra_suggests %in% imports])))
  }

  # Preserve existing version pins (e.g. "pkg (>= 1.0.0)") for packages that
  # stay in Imports/Suggests, no matter which of the two fields they were
  # previously listed under.
  fields <- read.dcf(desc_file, all = TRUE)
  existing_pins <- c(
    parse_dcf_deps(fields[["Imports"]]),
    parse_dcf_deps(fields[["Suggests"]])
  )

  format_deps <- function(pkgs) {
    if (length(pkgs) == 0L) {
      return(NULL)
    }
    entries <- vapply(pkgs, function(p) {
      pin <- existing_pins[[p]]
      if (is.null(pin) || !nzchar(pin)) p else paste0(p, " ", pin)
    }, character(1L))
    paste(entries, collapse = ",\n    ")
  }

  # Assigning NULL drops the field entirely when there's nothing to list.
  fields[["Imports"]] <- format_deps(imports)
  fields[["Suggests"]] <- format_deps(suggests)

  write.dcf(fields, file = desc_file, keep.white = c("Imports", "Suggests"))

  invisible(desc_file)
}
