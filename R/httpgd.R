

#' Asynchronous HTTP server graphics device.
#'
#' This function initializes a httpgd graphics device and
#' starts a local webserver, that allows for access via HTTP and WebSockets.
#' A link will be printed by which the web client can be accessed using
#' a browser.
#'
#' All font settings and descriptions are adopted from the excellent
#' 'svglite' package.
#'
#' @param host Server hostname. Set to `"0.0.0.0"` to enable remote access.
#'   We recommend to **only enable remote access in trusted networks**.
#'   The network security of httpgd has not yet been properly tested.
#' @param port Server port. If this is set to `0`, an open port
#'   will be assigned.
#' @param width Graphics device width (pixels).
#' @param height Graphics device height (pixels).
#' @param bg Background color.
#' @param pointsize Graphics device point size.
#' @param system_fonts Named list of font names to be aliased with
#'   fonts installed on your system. If unspecified, the R default
#'   families `sans`, `serif`, `mono` and `symbol`
#'   are aliased to the family returned by
#'   [systemfonts::font_info()].
#' @param user_fonts Named list of fonts to be aliased with font files
#'   provided by the user rather than fonts properly installed on the
#'   system. The aliases can be fonts from the fontquiver package,
#'   strings containing a path to a font file, or a list containing
#'   `name` and `file` elements with `name` indicating
#'   the font alias in the SVG output and `file` the path to a
#'   font file.
#' @param cors Toggles Cross-Origin Resource Sharing (CORS) header.
#'   When set to `TRUE`, CORS header will be set to `"*"`.
#' @param token (Optional) security token. When set, all requests
#'   need to include a token to be allowed. (Either in a request header
#'   (`X-HTTPGD-TOKEN`) field or as a query parameter.)
#'   This parameter can be set to `TRUE` to generate a random 8 character
#'   alphanumeric token. A random token of the specified length is generated
#'   when it is set to a number. `FALSE` deactivates the token.
#' @param silent When set to `FALSE` no information will be printed to console.
#' @param websockets Use websockets.
#' @param webserver Can be set to `FALSE` for offline mode.
#'   In offline mode the device is only accessible via R.
#' @param fix_text_width Should the width of strings be fixed so that it doesn't
#'   change between SVG renderers depending on their font rendering? Defaults to
#'   `TRUE`. If `TRUE` each string will have the `textLength` CSS property set
#'   to the width calculated by systemfonts and
#'   `lengthAdjust='spacingAndGlyphs'`. Setting this to `FALSE` can be
#'   beneficial for heavy post-processing that may change content or style of
#'   strings, but may lead to inconsistencies between strings and graphic
#'   elements that depend on the dimensions of the string (e.g. label borders
#'   and background).
#' @param extra_css Extra CSS to be added to the SVG. This can be used
#'   to embed webfonts.
#'
#' @return No return value, called to initialize graphics device.
#'
#' @importFrom systemfonts match_font
#' @export
#'
#' @examples
#' \dontrun{
#'
#' hgd() # Initialize graphics device and start server
#' hgd_browse() # Or copy the displayed link in the browser
#'
#' # Plot something
#' x <- seq(0, 3 * pi, by = 0.1)
#' plot(x, sin(x), type = "l")
#'
#' dev.off() # alternatively: hgd_close()
#' }
hgd <-
  function(host = "127.0.0.1",
           port = 0,
           width = 720,
           height = 576,
           bg = "white",
           pointsize = 12,
           system_fonts = list(),
           user_fonts = list(),
           cors = FALSE,
           token = TRUE,
           silent = FALSE,
           websockets = TRUE,
           webserver = TRUE,
           fix_text_width = TRUE,
           extra_css = "") {
    tok <- ""
    if (is.character(token)) {
      tok <- token
    } else if (is.numeric(token)) {
      tok <- httpgd_random_token_(token)
    } else if (is.logical(token) && token) {
      tok <- httpgd_random_token_(8)
    }

    aliases <- validate_aliases(system_fonts, user_fonts)
    if (httpgd_(
      host, port, bg, width, height,
      pointsize, aliases, cors, tok, webserver, silent,
      fix_text_width, extra_css
    )) {
      if (!silent && webserver) {
        cat("httpgd server running at:\n  ",
          hgd_url(websockets = websockets),
          "\n",
          sep = ""
        )
      }
    } else {
      hgd_close()
      stop("Failed to start server. (Port might be in use.)")
    }
  }

#' httpgd device status.
#'
#' Access status information of a httpgd graphics device.
#' This function will only work after starting a device with [hgd()].
#'
#' @param which Which device (ID).
#'
#' @return List of status variables with the following named items:
#'   `$host`: Server hostname,
#'   `$port`: Server port,
#'   `$token`: Security token,
#'   `$hsize`: Plot history size (how many plots are accessible),
#'   `$upid`: Update ID (changes when the device has received new information),
#'   `$active`: Is the device the currently activated device.
#'
#' @importFrom grDevices dev.cur
#' @export
#'
#' @examples
#' \dontrun{
#'
#' hgd()
#' hgd_state()
#' plot(1, 1)
#' hgd_state()
#'
#' dev.off()
#' }
hgd_state <- function(which = dev.cur()) {
  if (names(which) != "httpgd") {
    stop("Device is not of type httpgd")
  }
  else {
    return(httpgd_state_(which))
  }
}

#' Query httpgd plot IDs
#'
#' Query httpgd graphics device static plot IDs.
#' Available plot IDs starting from `index` will be returned.
#' `limit` specifies the number of plots.
#' This function will only work after starting a device with [hgd()].
#'
#' @param index Plot index. If this is set to `0`, the last page will be
#'   selected.
#' @param limit Limit the number of returned IDs. If this is set to a
#'  value > 1 the returned type is a list if IDs.
#' @param which Which device (ID).
#' @param state Include the current device state in the returned result
#'  (see also: [hgd_state()]).
#'
#' @return TODO
#'
#' @importFrom grDevices dev.cur
#' @export
#'
#' @examples
#' \dontrun{
#'
#' hgd()
#' plot.new()
#' text(.5, .5, "#1")
#' plot.new()
#' text(.5, .5, "#2")
#' plot.new()
#' text(.5, .5, "#3")
#' third <- hgd_id()
#' second <- hgd_id(2)
#' all <- hgd_id(1, limit = Inf)
#' hgd_remove(1)
#' hgd_svg(second)
#'
#' dev.off()
#' }
hgd_id <- function(index = 0, limit = 1, which = dev.cur(), state = FALSE) {
  if (names(which) != "httpgd") {
    stop("Device is not of type httpgd")
  }
  if (limit == 0 || is.infinite(limit)) {
    limit <- -1
  }
  res <- httpgd_id_(which, index - 1, limit)
  if (state) {
    return(res)
  }
  if (limit == 1) {
    return(res$plots[[1]])
  }
  return(res$plots)
}

#' Render httpgd plot to SVG.
#'
#' This function will only work after starting a device with [hgd()].
#'
#' @param page Plot page to render. If this is set to `0`, the last page will
#'   be selected. Can be set to a numeric plot index or plot ID
#'   (see [hgd_id()]).
#' @param width Width of the plot. If this is set to `-1`, the last width will
#'   be selected.
#' @param height Height of the plot. If this is set to `-1`, the last height
#'   will be selected.
#' @param which Which device (ID).
#' @param file Filepath to save SVG. (No file will be created if this is NA)
#'
#' @return Rendered SVG string.
#'
#' @importFrom grDevices dev.cur
#' @export
#'
#' @examples
#' \dontrun{
#'
#' hgd()
#' plot(1, 1)
#' s <- hgd_svg(width = 600, height = 400)
#' hist(rnorm(100))
#' hgd_svg(file = tempfile(), width = 600, height = 400)
#'
#' dev.off()
#' }
hgd_svg <- function(page = 0, width = -1, height = -1, which = dev.cur(),
                    file = NA) {
  if (names(which) != "httpgd") {
    stop("Device is not of type httpgd")
  }
  else {
    if (class(page) == "httpgd_pid") {
      svg <- httpgd_svg_id_(which, page$id, width, height)
    } else {
      svg <- httpgd_svg_(which, page - 1, width, height)
    }
    if (!is.na(file)) {
      cat(svg, file = file)
    }
    return(svg)
  }
}

#' Remove a httpgd plot page.
#'
#' This function will only work after starting a device with [hgd()].
#'
#' @param page Plot page to remove. If this is set to `0`, the last page will
#'   be selected. Can be set to a numeric plot index or plot ID
#'   (see [hgd_id()]).
#' @param which Which device (ID).
#'
#' @return Whether the page existed (and thereby was successfully removed).
#'
#' @importFrom grDevices dev.cur
#' @export
#'
#' @examples
#' \dontrun{
#'
#' hgd()
#' plot(1, 1) # page 1
#' hist(rnorm(100)) # page 2
#' hgd_remove(page = 1) # remove page 1
#'
#' dev.off()
#' }
hgd_remove <- function(page = 0, which = dev.cur()) {
  if (names(which) != "httpgd") {
    stop("Device is not of type httpgd")
  }
  else {
    if (class(page) == "httpgd_pid") {
      return(httpgd_remove_id_(which, page$id))
    }
    return(httpgd_remove_(which, page - 1))
  }
}

#' Clear all httpgd plot pages.
#'
#' This function will only work after starting a device with [hgd()].
#'
#' @param which Which device (ID).
#'
#' @return Whether there were any pages to remove.
#'
#' @importFrom grDevices dev.cur
#' @export
#'
#' @examples
#' \dontrun{
#'
#' hgd()
#' plot(1, 1)
#' hist(rnorm(100))
#' hgd_clear()
#' hist(rnorm(100))
#'
#' dev.off()
#' }
hgd_clear <- function(which = dev.cur()) {
  if (names(which) != "httpgd") {
    stop("Device is not of type httpgd")
  }
  else {
    return(httpgd_clear_(which))
  }
}


build_http_query <- function(x) {
  a <- unlist(lapply(x, paste))
  paste(names(a), a, sep = "=", collapse = "&")
}

#' httpgd URL.
#'
#' Generate URLs to the plot viewer or to plot SVGs.
#' This function will only work after starting a device with [hgd()].
#'
#' @param endpoint API endpoint. The default, `"live"` is the HTML/JS
#'   plot viewer. Can be set to a numeric plot index or plot ID
#'   (see [hgd_id()]) to obtain the direct URL to the SVG.
#' @param which Which device (ID).
#' @param websockets Use websockets.
#' @param width Width of the plot. (Only used when `endpoint` is `"svg"`,
#'   or a plot index or ID.)
#' @param height Height of the plot. (Only used when `endpoint` is `"svg"`,
#'   or a plot index or ID.)
#' @param history Should the plot history sidebar be visible.
#'
#' @return URL.
#'
#' @importFrom grDevices dev.cur
#' @export
#'
#' @examples
#' \dontrun{
#'
#' hgd()
#' my_url <- hgd_url()
#' hgd_url(0)
#' hgd_url(plot_id(), width = 800, height = 600)
#'
#' dev.off()
#' }
hgd_url <- function(
                    endpoint = "live",
                    which = dev.cur(),
                    websockets = TRUE,
                    width = -1,
                    height = -1,
                    history = TRUE) {
  l <- hgd_state(which)
  q <- list()
  if (is.numeric(endpoint) || (class(endpoint) == "httpgd_pid")) {
    if (is.numeric(endpoint)) {
      if (endpoint > 0) {
        q["index"] <- endpoint - 1
      }
    } else {
      q["id"] <- endpoint
    }
    endpoint <- "svg"
  }
  if (endpoint == "svg") {
    if (width > 0) {
      q["width"] <- width
    }
    if (height > 0) {
      q["height"] <- height
    }
  }
  if (nchar(l$token) > 0) {
    q["token"] <- l$token
  }
  if (!websockets) {
    q["ws"] <- "0"
  }
  if (!history) {
    q["sidebar"] <- "0"
  }
  paste0(
    "http://",
    sub("0.0.0.0", Sys.info()[["nodename"]], l$host, fixed = TRUE),
    ":",
    l$port,
    "/",
    endpoint,
    ifelse(length(q) == 0, "", paste0("?", build_http_query(q)))
  )
}

#' Open httpgd URL in the browser.
#'
#' This function will only work after starting a device with [hgd()].
#'
#' @param ... Parameters passed to [hgd_url()].
#' @param which Which device (ID).
#' @param browser Program to be used as HTML browser.
#'
#' @return URL.
#'
#' @importFrom grDevices dev.cur
#' @importFrom utils browseURL
#' @export
#'
#' @examples
#' \dontrun{
#'
#' hgd()
#' hgd_browse() # open browser
#' hist(rnorm(100))
#'
#' dev.off()
#' }
hgd_browse <- function(..., which = dev.cur(), browser = NULL) {
  if (is.null(browser)) {
    browser <- getOption("browser")
  }
  browseURL(hgd_url(..., which = which), browser)
}

#' Close httpgd device.
#'
#' This achieves the same effect as [grDevices::dev.off()],
#' but will only close the device if it has the httpgd type.
#'
#' @param which Which device (ID).
#' @param all Should all running httpgd devices be closed.
#'
#' @return Number and name of the new active device (after the specified device
#'   has been shut down).
#'
#' @importFrom grDevices dev.cur dev.list dev.off
#' @export
#'
#' @examples
#' \dontrun{
#'
#' hgd()
#' hgd_browse() # open browser
#' hist(rnorm(100))
#' hgd_close() # Equvalent to dev.off()
#'
#' hgd()
#' hgd()
#' hgd()
#' hgd_close(all = TRUE)
#' }
hgd_close <- function(which = dev.cur(), all = FALSE) {
  if (all) {
    ds <- dev.list()
    invisible(lapply(ds[names(ds) == "httpgd"], dev.off))
  } else {
    if (which != 1 && names(which(dev.list() == which)) == "httpgd") {
      dev.off(which)
    }
  }
}

#' Generate random alphanumeric token.
#'
#' This is mainly used internally by httpgd, but exposed for
#' testing purposes.
#'
#' @param len Token length (number of characters).
#'
#' @return Random token string.
#' @export
#'
#' @examples
#' hgd_generate_token(6)
hgd_generate_token <- function(len) {
  httpgd_random_token_(len)
}


#' Inline SVG rendering.
#'
#' Convenience function for quick inline SVG rendering.
#' This is similar to [hgd_svg()] but the plotting code is specified inline
#' and an offline httpgd graphics device is managed (created and closed)
#' automatically. Starting a device with [hgd()] is therefore not necessary.
#'
#' @param code Plotting code. See examples for more information.
#' @param page Plot page to render. If this is set to `0`, the last page will
#'   be selected. Can be set to a numeric plot index or plot ID
#'   (see [hgd_id()]).
#' @param page_width Width of the plot. If this is set to `-1`, the last width
#'   will be selected.
#' @param page_height Height of the plot. If this is set to `-1`, the last
#'   height will be selected.
#' @param file Filepath to save SVG. (No file will be created if this is `NA`)
#' @param ... Additional parameters passed to `hgd(webserver=FALSE, ...)`
#'
#' @return Rendered SVG string.
#' @export
#'
#' @examples
#' hgd_inline({
#'   hist(rnorm(100))
#' })
#'
#' s <- hgd_inline({
#'   plot.new()
#'   lines(c(0.5, 1, 0.5), c(0.5, 1, 1))
#' })
#' cat(s)
hgd_inline <- function(code, page = 0, page_width = -1, page_height = -1,
                       file = NA, ...) {
  hgd(webserver = FALSE, ...)
  tryCatch(code,
    finally = {
      s <- hgd_svg(page = page, width = page_width, height = page_height)
      dev.off()
    }
  )
  s
}
