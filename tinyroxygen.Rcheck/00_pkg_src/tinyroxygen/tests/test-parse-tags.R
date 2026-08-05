library(tinyroxygen)

tags <- tinyroxygen:::parse_block_tags(c(
  "#' Title line",
  "#'",
  "#' Description paragraph.",
  "#'",
  "#' @param x,y Two numbers.",
  "#' @export"
))

stopifnot(identical(tags$intro, c("Title line", "", "Description paragraph.", "")))
stopifnot(length(tags$tags) == 2)
stopifnot(identical(tags$tags[[1]]$tag, "param"))
stopifnot(identical(tags$tags[[1]]$value, "x,y Two numbers."))
stopifnot(identical(tags$tags[[2]]$tag, "export"))

info <- tinyroxygen:::object_info(quote(add <- function(x, y = 1) x + y))
stopifnot(identical(info$name, "add"))
stopifnot(isTRUE(info$is_function))
stopifnot(identical(info$usage, "add(x, y = 1)"))

cat("parse-tags test passed\n")
