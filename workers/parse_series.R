#!/usr/bin/env -S Rscript --vanilla

#ver="1.0.0" # currently unversioned

conn_stdin <- file("stdin", blocking=TRUE)
open(conn_stdin)

blocks <- list()
current_block <- list()
in_block <- FALSE

make_unique_meta_name <- function(candidate, names, slug=1) {
  if (! candidate %in% names) {
    return(candidate)
  }
  new_candidate <- paste0(candidate, "_", slug)
  if (! new_candidate %in% names) {
    return(new_candidate)
  }
  make_unique_meta_name(candidate, names, slug = slug + 1)
}

while (length(line <- readLines(conn_stdin, n=1)) > 0) {
  if (startsWith(line, "^SAMPLE") && in_block) {
    if (is.null(block_name)) {
      stop("We are in a block, but it has ended without a block name.")
    }
    # We are in a block, but it has ended. We need to flush it.
    blocks[[block_name]] <- data.frame(current_block) 
    current_block <- list()
    block_name <- NULL
    in_block <- FALSE
    # No next here since we want the new block to start, so we continue parsing.
  }

  if (startsWith(line, "^SAMPLE") && ! in_block) {
    # This is the start of a new block
    block_name <- {
      split <- strsplit(line, " = ", fixed=TRUE) |> unlist()
      split[length(split)]
    }
    in_block <- TRUE
    next
  }
  
  if (in_block) {
    # This is a line in a block. It should start with '!Sample_' and contain
    # some metadata about the sample.
    # NOTE: "geo_accession" key label is to be replaced with "geo_sample" to
    #       have a final metadata table that is "crossable" with ENA's.
    if (! startsWith(line, "!Sample_")) {
      warning(paste0("Line '", line, "' does not start with !Sample_ as expected. Trying to continue"))
      next
    }
    clean <- sub("!Sample_", "", line)
    xable <- sub("geo_accession", "geo_sample", clean)
    split <- strsplit(xable, " = ", fixed = TRUE) |> unlist()
    name <- make_unique_meta_name(split[1], names(current_block), 2)
    current_block[name] <- paste0(split[2:length(split)], collapse = " = ")
    next 
  }
}

# close the last block
blocks[[block_name]] <- data.frame(current_block)

# We have a list of blocks - we can print it out
dframe <- gtools::smartbind(list=blocks)
# Coerce everything as a character, just to be safe
row.names(dframe) <- NULL
dframe <- apply(dframe, 2, as.character)

out <- stdout()
write.csv(dframe, out, row.names = FALSE, quote=TRUE)
