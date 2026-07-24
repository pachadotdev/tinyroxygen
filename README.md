# tinyroxygen

A tiny, dependency-free alternative to 'roxygen2'. Reads `#'` comment blocks
above R functions/objects and writes `.Rd` files (`man/`) and a `NAMESPACE`,
using **base R only** — no `testthat`, `rlang`, `sass`, `pkgload`, etc. to
install. The tag-parsing work is just text + `parse()`/base R, which is more
than fast enough for typical package sizes.

There is one compiled dependency: a vendored, trimmed-down copy of 'cmark'
(see `src/cmark/`, vendored by `scripts/cmark.sh`), used to parse Markdown
into an AST for the `@md` tag (see below, opt-in per topic). It's wrapped
with base R's own C API, without the need for extra development tools such as
[cpp4r](https://github.com/pachadotdev/cpp4r).

## Usage

Clone the repository:

```sh
git clone --depth 1 https://github.com/pachadotdev/tinyroxygen.git
```

Install the package (a C compiler is required to build the vendored 'cmark'
parser used for `@md`):

```sh
cd tinyroxygen && R CMD INSTALL .
```

Then document your package using:

```sh
cd mypkg && R
```

```r
tinyroxygen::roxygenise(".")
```

## What it supports

Per `#'` block, right above a `name <- function(...) ...` or `name <- value`:

- Intro text: paragraph 1 = title, paragraph 2 = description, rest = details
  (or the explicit `@title`/`@description`/`@details` tags)
- `@param name description` (`@param x,y description` documents both `x` and `y`)
- `@inheritParams source` (fills in `@param` entries not already documented
  locally from another object's own `@param` tags; same-package objects
  only, a `pkg::fun` source has its `pkg::` prefix stripped and is looked
  up locally)
- `@return`/`@returns`
- `@examples`
- `@export`, `@exportS3Method`, `@exportClass`, `@exportMethod`
- `@import`, `@importFrom`, `@useDynLib`
- `@name`, `@rdname`, `@aliases`
- `@seealso`, `@keywords`
- `@family name` (adds an "Other name: ..." block linking to every other
  topic tagged with the same family name, folded into `\seealso{}`)
- `@noRd`
- `@md` (opt-in, per topic, or package-wide via `Config/tinyroxygen/markdown`
  in `DESCRIPTION`, see below)

By default, write plain text, or real Rd markup (`\code{}`, `\link{}`, ...)
directly in your comments, just like pre-markdown roxygen2. The only
automatic escaping is for a bare `%` (the Rd comment character), since
that's the most common footgun in prose.

```r
#' @title Add
#' 
#' @description Adds \code{x} and \code{y}, returning \strong{their sum}.
#' See \code{\link{multiply}} instead if you need a product.
#' 
#' @param x A number.
#' @param y A number.
add <- function(x, y) x + y
```

### Markdown (`@md`)

Add `@md` to a block (after its title/description/details text, like any
other tag) to write Markdown instead of Rd:

```r
#' @title Add
#' 
#' @description Adds `x` and `y`, returning **their sum**. See [multiply()]
#' for multiplication.
#' @md
#' 
#' @param x A number.
#' @param y A number.
add <- function(x, y) x + y
```

Adding `@md` to every block gets repetitive, so you can instead set
`Config/tinyroxygen/markdown: TRUE` in `DESCRIPTION` to turn Markdown on for
every topic in the package (this is a tinyroxygen-specific field, not
shared with roxygen2).

Only a small, unambiguous subset of Markdown is supported: paragraphs,
`*emphasis*`, `**strong**`, `` `code` `` spans, fenced/indented code blocks,
`[links](url)`, bullet/ordered lists, and topic autolinks (below). No
tables, headings, images, or raw HTML. Don't mix raw Rd markup into an
`@md` block either: text is treated as literal Markdown source, so a stray
`\code{\link{multiply}}` gets its own backslash/braces escaped instead of
being kept as Rd markup.

Like roxygen2, `@md` also supports topic autolinks - `[fun()]`, `[obj]`,
`` [`obj`] ``, and `[pkg::fun()]` all become `\link{}`/`\code{\link{}}`
cross-references without needing a real `(url)`, and `[text][ref]` lets you
give a link custom text:

| Markdown                    | Rd                                            |
| --------------------------- | --------------------------------------------- |
| `[multiply()]`              | `\code{\link[=multiply]{multiply()}}`         |
| `[multiply]`                | `\link{multiply}`                             |
| `` [`multiply`] ``          | `\code{\link{multiply}}`                      |
| `[pkg::multiply()]`         | `\code{\link[pkg:multiply]{pkg::multiply()}}` |
| `[the product][multiply()]` | `\link[=multiply]{the product}`               |

Unlike roxygen2, tinyroxygen does not check that the linked topic or package
actually exists - it just rewrites the syntax, with no package introspection.

## What it doesn't do

No `Collate` management, no S4/R6/S7 introspection, no vignette roclet, no
automatic `@param` from function formals. `@inheritParams` doesn't resolve
across packages and doesn't check that inherited params actually match the
current function's formals - it just copies over any `@param` entries not
already documented locally. If your package needs more than that, use
'roxygen2'.
