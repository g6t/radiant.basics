#' Calculate correlations for two or more variables
#'
#' @details See \url{https://radiant-rstats.github.io/docs/basics/correlation.html} for an example in Radiant
#'
#' @param dataset Dataset name (string). This can be a dataframe in the global environment or an element in an r_data list from Radiant
#' @param vars Variables to include in the analysis. Default is all but character and factor variables with more than two unique values are removed
#' @param method Type of correlations to calculate. Options are "pearson", "spearman", and "kendall". "pearson" is the default
#' @param data_filter Expression entered in, e.g., Data > View to filter the dataset in Radiant. The expression should be a string (e.g., "price > 10000")
#'
#' @return A list with all variables defined in the function as an object of class compare_means
#'
#' @examples
#' result <- correlation("diamonds", c("price","carat"))
#' result <- correlation("diamonds", c("price","carat","table"))
#' result <- correlation("diamonds", "price:carat")
#' result <- diamonds %>% correlation("price:carat")
#'
#' @seealso \code{\link{summary.correlation}} to summarize results
#' @seealso \code{\link{plot.correlation}} to plot results
#'
#' @export
correlation <- function(dataset, vars = "",
                        method = "pearson",
                        data_filter = "") {

  ## data.matrix as the last step in the chain is about 25% slower using
  ## system.time but results (using diamonds and mtcars) are identical
  dat <- getdata(dataset, vars, filt = data_filter) %>%
    # select_if(!is.character) %>%
    mutate_all(funs(as_numeric))

  if (!is_string(dataset)) dataset <- deparse(substitute(dataset)) %>% set_attr("df", TRUE)
  as.list(environment()) %>% add_class("correlation")
}

#' Summary method for the correlation function
#'
#' @details See \url{https://radiant-rstats.github.io/docs/basics/correlation.html} for an example in Radiant
#'
#' @param object Return value from \code{\link{correlation}}
#' @param cutoff Show only corrlations larger than the cutoff in absolute value. Default is a cutoff of 0
#' @param covar Show the covariance matrix (default is FALSE)
#' @param dec Number of decimals to show
#' @param ... further arguments passed to or from other methods.
#'
#' @examples
#' result <- correlation("diamonds",c("price","carat","table"))
#' summary(result, cutoff = .3)
#' diamonds %>% correlation("price:carat") %>% summary
#'
#' @seealso \code{\link{correlation}} to calculate results
#' @seealso \code{\link{plot.correlation}} to plot results
#'
#' @importFrom psych corr.test
#'
#' @export
summary.correlation <- function(object,
                                 cutoff = 0,
                                 covar = FALSE,
                                 dec = 2,
                                 ...) {

  ## calculate the correlation matrix with p.values using the psych package
  cmat <- sshhr(psych::corr.test(object$dat, method = object$method))

  cr <- apply(cmat$r, 2, formatnr, dec = dec) %>%
    format(justify = "right") %>%
    set_rownames(rownames(cmat$r))
  cr[is.na(cmat$r)] <- "-"
  cr[abs(cmat$r) < cutoff] <- ""
  ltmat <- lower.tri(cr)
  cr[!ltmat] <- ""

  cp <- apply(cmat$p, 2, formatnr, dec = dec) %>%
    format(justify = "right") %>%
    set_rownames(rownames(cmat$p))
  cp[is.na(cmat$p)] <- "-"
  cp[abs(cmat$r) < cutoff] <- ""
  cp[!ltmat] <- ""

  cat("Correlation\n")
  cat("Data     :", object$dataset, "\n")
  cat("Method   :", object$method, "\n")
  if (cutoff > 0)
    cat("Cutoff   :", cutoff, "\n")
  if (object$data_filter %>% gsub("\\s","",.) != "")
    cat("Filter   :", gsub("\\n","", object$data_filter), "\n")
  cat("Variables:", paste0(object$vars, collapse = ", "), "\n")
  cat("Null hyp.: variables x and y are not correlated\n")
  cat("Alt. hyp.: variables x and y are correlated\n\n")

  cat("Correlation matrix:\n")
  print(cr[-1,-ncol(cr), drop = FALSE], quote = FALSE)

  cat("\np.values:\n")
  print(cp[-1,-ncol(cp), drop = FALSE], quote = FALSE)

  if (covar) {
    cvmat <- sshhr( cov(object$dat, method = object$method) )
    cvr <- apply(cvmat, 2, formatnr, dec = dec) %>%
      format(justify = "right") %>%
      set_rownames(rownames(cvmat))
    cvr[abs(cmat$r) < cutoff] <- ""
    ltmat <- lower.tri(cvr)
    cvr[!ltmat] <- ""

    cat("\nCovariance matrix:\n")
    print(cvr[-1,-ncol(cvr), drop = FALSE], quote = FALSE)
  }

  rm(object)
}

#' Plot method for the correlation function
#'
#' @details See \url{https://radiant-rstats.github.io/docs/basics/correlation.html} for an example in Radiant
#'
#' @param x Return value from \code{\link{correlation}}
#' @param n Number of datapoints to use in the plot (1,000 is default). Use -1 for all observations
#' @param jit Level of jittering to apply to scatter plot. Default is .3. Use 0 for no jittering
#' @param ... further arguments passed to or from other methods.
#'
#' @examples
#' result <- correlation("diamonds",c("price","carat","table"))
#' plot(result)
#' diamonds %>% correlation("price:carat") %>% plot
#'
#' @seealso \code{\link{correlation}} to calculate results
#' @seealso \code{\link{summary.correlation}} to summarize results
#'
#' @importFrom ggplot2 alpha
#'
#' @export
plot.correlation <- function(x, n = 1000, jit = .3, ...) {

  object <- x; rm(x)

  ## based mostly on http://gallery.r-enthusiasts.com/RGraphGallery.php?graph=137
  panel.plot <- function(x, y) {
    usr <- par("usr"); on.exit(par(usr))
    par(usr = c(0, 1, 0, 1))
    ct <- sshhr(cor.test(x,y, method = object$method))
    sig <- symnum(ct$p.value, corr = FALSE, na = FALSE,
                  cutpoints = c(0, 0.001, 0.01, 0.05, 0.1, 1),
                  symbols = c("***", "**", "*", ".", " "))
    r <- ct$estimate
    rt <- format(r, digits = 2)[1]
    cex <- 0.5/strwidth(rt)

    text(.5, .5, rt, cex = cex * abs(r))
    text(.8, .8, sig, cex = cex, col = "blue")
  }
  panel.smooth <- function(x, y) {
    if(n > 0 & length(x) > n) {
      ind <- sample(1:length(x), n)
      x <- x[ind]
      y <- y[ind]
    }
    points(jitter(x,jit), jitter(y,jit), pch = 16, 
      col = ggplot2::alpha("black", 0.5))
    ## uncomment the lines below if you want linear and loess lines
    ## in the scatter plot matrix
    # abline(lm(y~x), col="red")
    # lines(stats::lowess(y~x), col="blue")
  }

  object$dat %>% {if (is.null(.)) object else . } %>%
    pairs(lower.panel = panel.smooth, upper.panel = panel.plot)
}
