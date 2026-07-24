/* cmark/cmark.c (vendored, unmodified) defines the convenience function
 * cmark_markdown_to_html(), which calls cmark_render_html() - normally
 * defined in cmark/html.c. We intentionally don't vendor html.c/render.c
 * (only the CommonMark parser + AST are needed here; Rd rendering is done
 * in R, see R/markdown.R), and tinyroxygen never calls
 * cmark_markdown_to_html() itself, but its mere presence in cmark.c leaves
 * an unresolved reference to cmark_render_html(). Some modern toolchains
 * bind shared-library symbols eagerly at load time (e.g. via -z now),
 * which would fail to load the package DLL over a genuinely missing
 * symbol. This stub satisfies the linker without vendoring the HTML
 * renderer; it is dead code and is never actually invoked.
 */
#include "cmark/cmark.h"

char *cmark_render_html(cmark_node *root, int options) {
  (void) root;
  (void) options;
  return NULL;
}
