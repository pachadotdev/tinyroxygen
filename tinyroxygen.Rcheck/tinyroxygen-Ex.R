pkgname <- "tinyroxygen"
source(file.path(R.home("share"), "R", "examples-header.R"))
options(warn = 1)
library('tinyroxygen')

base::assign(".oldSearch", base::search(), pos = 'CheckExEnv')
base::assign(".old_wd", base::getwd(), pos = 'CheckExEnv')
cleanEx()
nameEx("roxygenise")
### * roxygenise

flush(stderr()); flush(stdout())

### Name: roxygenise
### Title: Generate documentation from roxygen comments
### Aliases: roxygenise roxygenize

### ** Examples

## Not run: 
##D roxygenise("path/to/package")
## End(Not run)



### * <FOOTER>
###
cleanEx()
options(digits = 7L)
base::cat("Time elapsed: ", proc.time() - base::get("ptime", pos = 'CheckExEnv'),"\n")
grDevices::dev.off()
###
### Local variables: ***
### mode: outline-minor ***
### outline-regexp: "\\(> \\)?### [*]+" ***
### End: ***
quit('no')
