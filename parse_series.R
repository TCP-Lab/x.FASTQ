#!/usr/bin/env Rscript --vanilla

conn_stdin <- file("stdin", blocking=TRUE)
open(conn_stdin)

blocks <- list()
current_block <- list()
in_block <- FALSE

while (length(line <- readLines(conn_stdin, n=1)) > 0) {
  if (startsWith(line, "^SAMPLE") && in_block) {
    if (is.null(block_name)) {
      stop("We are in a block, but it has ended without a block name.")
    }
    # We are in a block, but it has ended. We need to flush it.
    blocks[[block_name]] <- current_block 
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
    if (! startsWith(line, "!Sample_")) {
      warning(paste0("Line '", line, "' does not start with !Sample_ as expected. Trying to continue"))
      next
    }
    clean <- sub("!Sample_", "", line)
    split <- strsplit(clean, " = ", fixed = TRUE) |> unlist()
    current_block[split[1]] <- paste0(split[2:length(split)], collapse = " = ")
    next 
  }
}

# close the last block
blocks[[block_name]] <- current_block 

# We have a list of blocks - we can print it out
dframe <- do.call(rbind, blocks)

out <- stdout()
write.csv(dframe, out, row.names = FALSE)

