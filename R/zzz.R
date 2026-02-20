# R/zzz.R
#
# Package load hook. S7 requires methods_register() to be called in .onLoad()
# so that methods on external generics (print, summary, etc.) are registered
# correctly when the package is loaded from an installed library.
# See: vignette("packages", package = "S7")

# nocov start
.onLoad <- function(libname, pkgname) {
  S7::methods_register()
}
# nocov end
