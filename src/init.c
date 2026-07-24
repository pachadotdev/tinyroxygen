/* Native routine registration, following the same base-R-C-API pattern
 * used by r-lib/commonmark (no Rcpp/cpp11/cpp4r). */
#include <stdlib.h>
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

SEXP R_parse_markdown(SEXP text);

static const R_CallMethodDef CallEntries[] = {
  {"R_parse_markdown", (DL_FUNC) &R_parse_markdown, 1},
  {NULL, NULL, 0}
};

void R_init_tinyroxygen(DllInfo *dll) {
  R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
