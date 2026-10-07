function (variables = NULL, repweights = NULL, weights = NULL, 
    data = NULL, degf = NULL, type = c("BRR", "Fay", "JK1", "JKn", 
        "bootstrap", "ACS", "successive-difference", "JK2", "other"), 
    combined.weights = TRUE, rho = NULL, bootstrap.average = NULL, 
    scale = NULL, rscales = NULL, fpc = NULL, fpctype = c("fraction", 
        "correction"), mse = getOption("survey.replicates.mse"), 
    ...) 
{
    type <- match.arg(type)
    if (type == "Fay" && is.null(rho)) 
        stop("With type='Fay' you must supply the correct rho")
    if (type %in% c("JK1", "JKn", "ACS", "successive-difference", 
        "JK2") && !is.null(rho)) 
        warning("rho not relevant to JK1 design: ignored.")
    if (type %in% c("other") && !is.null(rho)) 
        warning("rho ignored.")
    if (is.null(variables)) 
        variables <- data
    if (inherits(variables, "formula")) {
        mf <- substitute(model.frame(variables, data = data, 
            na.action = na.pass))
        variables <- eval.parent(mf)
    }
    variables <- detibble(variables)
    if (inherits(repweights, "formula")) {
        mf <- substitute(model.frame(repweights, data = data))
        repweights <- eval.parent(mf)
    }
    if (is.character(repweights)) {
        wtcols <- grep(repweights, names(data))
        repweights <- data[, wtcols]
    }
    if (is.null(repweights)) 
        stop("You must provide replication weights")
    if (anyNA(repweights)) 
        stop("Missing values not allowed in 'repweights'")
    repweights <- detibble(repweights)
    if (inherits(weights, "formula")) {
        mf <- substitute(model.frame(weights, data = data))
        weights <- eval.parent(mf)
        if (anyNA(weights)) 
            stop("Missing values not allowed in 'weights'")
        weights <- drop(as.matrix(weights))
    }
    if (is.null(weights)) {
        warning("No sampling weights provided: equal probability assumed")
        weights <- rep(1, NROW(repweights))
    }
    if (!is.null(degf)) {
        if (!is.numeric(degf)) 
            stop("degf must be NULL or numeric")
        if (degf > ncol(repweights)) 
            warning(paste0("degf (", degf, ") is larger than number of replicates (", 
                ncol(repweights), ")"))
        if (degf <= 1) 
            warning("degf is <=1")
        attr(degf, "set-by-user") <- TRUE
    }
    repwtmn <- mean(apply(repweights, 2, mean))
    wtmn <- mean(weights)
    probably.combined.weights <- (repwtmn > 5) & (wtmn/repwtmn < 
        5)
    probably.not.combined.weights <- (repwtmn < 5) & (wtmn/repwtmn > 
        5)
    if (combined.weights & probably.not.combined.weights) 
        warning(paste("Data do not look like combined weights: mean replication weight is", 
            repwtmn, " and mean sampling weight is", wtmn))
    if (!combined.weights & probably.combined.weights) 
        warning(paste("Data look like combined weights: mean replication weight is", 
            repwtmn, " and mean sampling weight is", wtmn))
    if (!is.null(rscales) && !(length(rscales) %in% c(1, ncol(repweights)))) {
        stop(paste("rscales has length ", length(rscales), ", should be ncol(repweights)", 
            sep = ""))
    }
    if (type %in% c("ACS", "successive-difference")) {
        if (!is.null(scale) | !is.null(rscales)) 
            warning(paste("with type", type, "scale= and rscales= are not needed and will be ignored"))
    }
    if (type == "BRR") {
        if (!is.null(scale)) 
            warning("type='BRR' does not use 'scale=' argument")
        if (!is.null(rho)) 
            warning("type='BRR' does not use 'rho=' argument, you may want type='Fay'")
        scale <- 1/ncol(repweights)
    }
    if (type == "Fay") 
        scale <- 1/(ncol(repweights) * (1 - rho)^2)
    if (type == "bootstrap") {
        if (is.null(bootstrap.average)) 
            bootstrap.average <- 1
        if (is.null(scale)) 
            scale <- bootstrap.average/(ncol(repweights) - 1)
        if (is.null(rscales)) 
            rscales <- rep(1, ncol(repweights))
    }
    if (type == "JK1" && is.null(scale)) {
        if (!combined.weights) {
            warning("scale (n-1)/n not provided: guessing from weights")
            scale <- 1/max(repweights[, 1])
        }
        else {
            probably.n = ncol(repweights)
            scale <- (probably.n - 1)/probably.n
            warning("scale (n-1)/n not provided: guessing n=number of replicates")
        }
    }
    if (type == "JKn" && is.null(rscales)) {
        if (!combined.weights) {
            warning("rscales (n-1)/n not provided:guessing from weights")
            rscales <- 1/apply(repweights, 2, max)
        }
        else stop("Must provide rscales for combined JKn weights")
    }
    if (type %in% c("ACS", "successive-difference")) {
        rscales <- rep(1, ncol(repweights))
        scale <- 4/ncol(repweights)
    }
    if (type == "JK2") {
        warning(paste("with type", type, "scale= and rscales= are not needed and will be ignored"))
        rscales <- rep(1, ncol(repweights))
        scale <- 1
    }
    if (type == "other" && (is.null(rscales) || is.null(scale))) {
        if (is.null(rscales)) 
            rscales <- rep(1, NCOL(repweights))
        if (is.null(scale)) 
            scale <- 1
        warning("scale or rscales not specified, set to 1")
    }
    if (is.null(rscales)) 
        rscales <- rep(1, NCOL(repweights))
    if (!is.null(fpc)) {
        if (missing(fpctype)) 
            stop("Must specify fpctype")
        fpctype <- match.arg(fpctype)
        if (type %in% c("BRR", "Fay", "JK2", "ACS", "successive-difference")) 
            stop("fpc not available for this type")
        if (type %in% "bootstrap") 
            stop("Separate fpc not needed for bootstrap")
        if (length(fpc) != length(rscales)) 
            stop("fpc is wrong length")
        if (any(fpc > 1) || any(fpc < 0)) 
            stop("Illegal fpc value")
        fpc <- switch(fpctype, correction = fpc, fraction = 1 - 
            fpc)
        rscales <- rscales * fpc
    }
    if (is.null(scale)) 
        scale <- 1
    rval <- list(type = type, scale = scale, rscales = rscales, 
        rho = rho, call = sys.call(), combined.weights = combined.weights)
    rval$variables <- variables
    rval$pweights <- weights
    if (!inherits(repweights, "repweights")) 
        class(rval) <- "repweights"
    rval$repweights <- repweights
    class(rval) <- "svyrep.design"
    if (!is.null(degf)) 
        rval$degf <- degf
    else rval$degf <- degf(rval)
    if (type == "ACS") {
        if (missing(mse) && !mse) {
            mse <- TRUE
            message("mse=TRUE assumed for type=\"ACS\"")
        }
        else if (!mse) {
            warning("The ACS uses MSE standard errors but you have specified mse=FALSE")
        }
    }
    rval$mse <- mse
    rval
}
