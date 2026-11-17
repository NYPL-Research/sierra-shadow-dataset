#!/usr/local/bin//Rscript --vanilla


# ------------------------------ #
rm(list=ls())

options(echo=TRUE)
options(width=80)
options(warn=2)
options(scipen=10)
options(datatable.prettyprint.char=50)
options(datatable.print.class=TRUE)
options(datatable.print.keys=TRUE)
options(datatable.fwrite.sep='\t')
options(datatable.na.strings="")

args <- commandArgs(trailingOnly=TRUE)

require(colorout)
library(data.table)
library(magrittr)
library(stringr)
library(libbib)

# ------------------------------ #

# Makes the next historical circ file from the export made in July.
#
# Run it once a year, after the July export is finished (after step 4)
# and before the next export is made.
#
# Step 4 gets the current fiscal year by subtracting an item's total
# checkouts in the last July export from its total checkouts now.
# So a July export already has every fiscal year in it. This keeps
# those columns, and total checkouts, for next year.
#
# Every row of the export is kept. Nothing is joined, so no item
# can be dropped.
#
# Sierra's yearly counters aren't used
# (see rebuild-fy21-to-fy24.R for why)


# the export in ../target/ has to be the one made in July
tmp <- fread_plus_date("../target/sierra-all-healed-joined.dat.gz", nrows=0)
expdate <- attr(tmp, "lb.date")
fycols <- names(tmp) %>% str_subset("^fy\\d\\d_checkouts$")

expdate
fycols

if(format(as.Date(expdate), "%m") != "07")
  stop("the export in ../target/ wasn't made in July")

# the newest fiscal year in the export has to be the one that just ended
lastfy <- fycols %>% sort %>% tail(1) %>% str_extract("^fy\\d\\d")
if(lastfy != format(as.Date(expdate), "fy%y"))
  stop("the newest fiscal year in the export isn't the one that just ended")

outfile <- sprintf("../data/historical-circ/historical-circ-fy17-%s.dat.gz",
                   lastfy)
if(file.exists(outfile))
  stop("the output file already exists. I won't overwrite it")


dat <- fread_plus_date("../target/sierra-all-healed-joined.dat.gz",
                       select=c("bibid", "itemid", fycols, "total_checkouts"))

setnames(dat, "total_checkouts", "total_checkouts_at_last_july")
setcolorder(dat, c("bibid", "itemid", fycols, "total_checkouts_at_last_july"))

dat[,.N]
dat[, uniqueN(itemid)]
dat[is.na(total_checkouts_at_last_july), .N]     # should be 0
dat[, lapply(.SD, sum, na.rm=TRUE), .SDcols=patterns("^fy")]


## debugging
# this was a book about knots that
# I took out 2020-12
dat[bibid==11315077]
dat[itemid==14021710]

dat[bibid==20869063]     # :)


dat %>% fwrite(outfile)


#############################################################
##### AFTER THIS, THESE HAVE TO CHANGE IN STEP 4        #####
##### (../4-add-historical-circ/)                       #####
#############################################################
#
#   - the date in the check that "ensures that years aren't messed up"
#   - the name of the historical circ file
#   - `lastjuly`, and the name of the column for the new fiscal year
#   - the two places where the `bib_fy` sums are made
#   - `finalorder`
