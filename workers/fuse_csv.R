#!/usr/bin/env -S Rscript --vanilla

ver="1.0.0"

args <- commandArgs(trailingOnly = TRUE)

data <- list()
fuse_col <- "auto"
i <- 1

while (i <= length(args)) {
  # Handle the (possible) -r flag for direct (raw) data input from command line.
  if (args[i] == "-r" || args[i] == "--raw") {
    # I tried to use append(), but for some fucking reason it coerces the
    # frames to lists, THEN appends, and there is no way to stop it.
    # Fuck me.
    data[[length(data) + 1]] <- read.csv(text = args[i + 1])
    i <- i + 2
    next
  }
  
  # Set the columns used for merging.
  if (args[i] == "-c" || args[i] == "--col") {
    fuse_col <- args[i+1]
    i <- i + 2
    next
  }

  # Input data from file.
  data[[length(data) + 1]] <- read.csv(args[i])
  
  i <- i + 1
}

# We now have all the data - fuse them
merged <- Reduce(\(x, y){merge(x, y, by = as.character(fuse_col), all = TRUE)},
                 data)

write.csv(file = stdout(), merged, row.names = FALSE)
