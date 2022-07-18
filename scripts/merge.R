#! /usr/bin/env Rscript --vanilla

#
# This script will merge two different trait dictionaries of the same crop
# into a single trait dictionary, following the CO file formatting conventions.
#


# File paths
EXISTING = NA         # existing CO file path
UPDATED = NA          # updated CO file path
MERGED = NA           # merged CO file path

# SEPARATORS
EXISTING_SEP = ","
UPDATED_SEP = ";"
MERGED_SEP = ","

# QUOTES
EXISTING_QUOTE = "\""
UPDATED_QUOTE = "\""
MERGED_QUOTE = "needed"

# Actions for added/removed variables
REMOVE_EXISTING = TRUE
ADD_NEW = TRUE


# Check arguments
args = commandArgs(trailingOnly=TRUE)
if ( length(args) == 2 ) {
    EXISTING = args[1]
    UPDATED = args[2]
    MERGED = "merged.csv"
} else if ( length(args) == 3 ) {
    EXISTING = args[1]
    UPDATED = args[2]
    MERGED = args[3]
} else {
    stop("USAGE: merge.R <exising.csv> <updated.csv> [merged.csv]")
}

# Check files
if ( !file.exists(EXISTING) ) {
    stop(sprintf("ERROR: Existing input file '%s' does not exist", EXISTING))
}
if ( !file.exists(UPDATED) ) {
    stop(sprintf("ERROR: Updated input file '%s' does not exist", UPDATED))
}


library(tidyverse)


# Print File Names
print(sprintf("Existing Trait Onology: %s", EXISTING))
print(sprintf("Updated Trait Ontology: %s", UPDATED))


# Read the input files
existing = as_tibble(read.csv(EXISTING, sep=EXISTING_SEP, quote=EXISTING_QUOTE, row.names=NULL))
updated = as_tibble(read.csv(UPDATED, sep=UPDATED_SEP, quote=UPDATED_QUOTE, row.names=NULL))
merged = tibble()


# Build summary table (which variables are in each file)
summary = tibble(
    variable = sort(unique(c(existing$`Variable.ID`, updated$`Variable.ID`))),
    existing = FALSE,
    updated = FALSE
)
summary[which(summary$variable %in% existing$`Variable.ID`),]$existing = TRUE
summary[which(summary$variable %in% updated$`Variable.ID`),]$updated = TRUE


# Print Summary
variables_both = filter(summary, existing == TRUE, updated == TRUE)$variable
variables_existing = filter(summary, existing == TRUE, updated == FALSE)$variable
variables_updated = filter(summary, existing == FALSE, updated == TRUE)$variable

print("CHANGES TO MAKE:")
print(sprintf("==> TO UPDATE: Variables in both files (%d)", length(variables_both)))
print(sprintf("==> TO %s: Variables just in existing (%d)", ifelse(REMOVE_EXISTING, "REMOVE", "KEEP"), length(variables_existing)))
if ( length(variables_existing) > 0 ) {
    paste(variables_existing, collapse=" ")
}
print(sprintf("==> TO %s: Variables just in updated (%d)", ifelse(ADD_NEW, "ADD", "SKIP"), length(variables_updated)))
if ( length(variables_updated) > 0 ) {
    paste(variables_updated, collapse=" ")
}


# Update existing data
for ( i in c(1:nrow(existing)) ) {
    e = existing[i,]
    id = e$Variable.ID

    # Get the updated information
    if ( id %in% variables_both || (id %in% variables_existing && !REMOVE_EXISTING) ) {
        m = filter(updated, Variable.ID == id)
        merged = rbind(merged, m)
    }
}

# Add new data
if ( ADD_NEW ) {
    for ( id in variables_updated ) {
        u = filter(updated, Variable.ID == id)
        merged = rbind(merged, u)
    }
}

# Update Column Names
colnames(merged) = unlist(lapply(colnames(merged), function(x) { gsub("\\.", " ", x) }))


# Write the merged file
write_delim(merged, MERGED, delim=MERGED_SEP, quote=MERGED_QUOTE, na="")
print(sprintf("Merged Trait Ontology: %s", MERGED))
