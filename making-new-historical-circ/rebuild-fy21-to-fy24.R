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

# Builds the historical circ file from archived exports.
# This only had to be done once. From now on `update.R` makes the
# new historical circ file each July.
#
# It rebuilds FY21 to FY24, which were wrong, and it adds FY25 and FY26.
# It also fills in FY17 to FY20 for items that had been dropped
#
# Sierra's lifetime counter (total_checkouts) is exactly the sum of its
# yearly counters. So, in any export,
#
#     total_checkouts - (the year-to-date counter)
#
# is an item's lifetime checkouts as of the last time the counters were
# reset. The difference between that number in two exports is the
# checkouts between the two resets, no matter what the reset did to the
# yearly counters.
#
# The counters were reset around 2021-07-30, 2022-07-09 and 2023-07-15.
# The 2022 reset did not save the year it ended, so the fy22 column
# of the historical circ file was wrong.
#
# A reset also skips some items (39% of the research items that
# circulated, in 2023). A skipped item's year-to-date counter just
# keeps running, and its last-year counter keeps the year before's
# number. So Sierra's yearly counters can't be used as they are.
#
# From FY25 on, the yearly counters aren't used at all. A fiscal year
# is the difference in total_checkouts between two July exports.
# The last column of the file is every item's total_checkouts in the
# latest July export. Step 4 uses it to get the current year.


#################################################
##### WHERE THE ARCHIVED EXPORTS ARE STORED #####
#################################################

archive <- "~/data/xfer/"

# the latest export made in July
latestdir  <- "../target/"
latestfile <- "sierra-all-healed-joined-2026-07-07.dat.gz"

infile  <- "../data/historical-circ/historical-circ-fy17-fy24.dat.gz"
outfile <- "../data/historical-circ/historical-circ-fy17-fy26.dat.gz"

if(file.exists(outfile))
  stop("the output file already exists. I won't overwrite it")


# total checkouts, the year-to-date counter, and the created date
# of every item in an archived export.
# `ytdcol` is the column holding the year-to-date counter in that export
read_export <- function(fname, ytdcol, dir=archive){
  tmp <- fread(sprintf("%s%s", dir, fname),
               select=c("itemid", "created_date", "total_checkouts", ytdcol),
               colClasses=c("created_date"="character"))
  setnames(tmp, ytdcol, "ytd")
  tmp[is.na(ytd), ytd:=0L]
  # a few items are in an export more than once
  # and some of their rows have no total checkouts
  tmp <- tmp[!is.na(total_checkouts)]
  ret <- tmp[, .(total=max(total_checkouts), ytd=max(ytd)), itemid]
  created <- unique(tmp[, .(itemid, created_date)], by="itemid")
  ret[created, on="itemid", created_date:=i.created_date]
  ret
}

# lifetime checkouts as of a counter reset.
# `after` is an export from after the reset and `before` is one from
# before it. Normally it's total checkouts minus the year-to-date
# counter in `after`.
# An item that the reset skipped has a counter that is bigger than
# everything it has done since `before`. For those, the total in
# `closest` (the export closest to the reset) is used instead
lifetime_at_reset <- function(after, before, closest=before){
  ret <- copy(after)
  ret[before,  on="itemid", beforetotal:=i.total]
  ret[closest, on="itemid", closesttotal:=i.total]
  ret[, skipped:=!is.na(beforetotal) & !is.na(closesttotal) &
                 ytd > total-beforetotal]
  ret[, atreset:=total-ytd]
  ret[skipped==TRUE, atreset:=closesttotal]
  ret[, .(itemid, created_date, atreset, skipped)]
}


old <- fread(infile)

old[,.N]
old[, lapply(.SD, sum, na.rm=TRUE), .SDcols=patterns("^fy")]


# --------------------------------------------------------------- #

#########################
####  ROWS OF THE NEW FILE

# one row for every bib/item pair in the latest July export
hist <- fread(sprintf("%s%s", latestdir, latestfile),
              select=c("bibid", "itemid"))
hist <- unique(hist)

# FY17 to FY24 as they are in the old file.
# They belong to the item so every row of an item gets them
oldbyitem <- unique(old, by="itemid")
oldbyitem[, bibid:=NULL]
hist <- merge(hist, oldbyitem, by="itemid", all.x=TRUE)
setcolorder(hist, c("bibid", "itemid"))

hist[,.N]
hist[, uniqueN(itemid)]

rm(old)
rm(oldbyitem)
gc()


# --------------------------------------------------------------- #

#################
####  FY17 TO FY20

# the old historical circ file is missing these years for some items
# (the old update.R dropped any item that wasn't already in the file).
# The 2021-07-11 export still has them

topup <- fread(sprintf("%s%s", archive,
                       "sierra-all-healed-joined-2021-07-11--revision-1.dat.gz"),
               select=c("itemid", "fy17_checkouts", "fy18_checkouts",
                        "fy19_checkouts", "fy20_checkouts"))
# a few items are in the export more than once
topup <- topup[, lapply(.SD, max), itemid]

hist[, lapply(.SD, sum, na.rm=TRUE), .SDcols=patterns("^fy(17|18|19|20)")]

# only where the file has nothing. it never changes a value that's there
hist[topup, on="itemid",
     `:=`(fy17_checkouts=fcoalesce(fy17_checkouts, i.fy17_checkouts),
          fy18_checkouts=fcoalesce(fy18_checkouts, i.fy18_checkouts),
          fy19_checkouts=fcoalesce(fy19_checkouts, i.fy19_checkouts),
          fy20_checkouts=fcoalesce(fy20_checkouts, i.fy20_checkouts))]
# in this file, an item with no checkouts in a year is NA and not 0
hist[fy17_checkouts==0, fy17_checkouts:=NA]
hist[fy18_checkouts==0, fy18_checkouts:=NA]
hist[fy19_checkouts==0, fy19_checkouts:=NA]
hist[fy20_checkouts==0, fy20_checkouts:=NA]

hist[, lapply(.SD, sum, na.rm=TRUE), .SDcols=patterns("^fy(17|18|19|20)")]

rm(topup)
gc()


# --------------------------------------------------------------- #

################################
####  LIFETIME AT EACH RESET

# in the 2021-07-11 export the counters had not been reset yet,
# so its year-to-date counter is in the column called fy21_checkouts.
# It's the same in the 2023-07-10 export, with fy23_checkouts
e20210711 <- read_export("sierra-all-healed-joined-2021-07-11--revision-1.dat.gz",
                         "fy21_checkouts")
e20211028 <- read_export("sierra-all-healed-joined-2021-10-28.dat.gz",
                         "fy22_checkouts")
# (these two only have branch items)
e20220430 <- read_export("sierra-branch-healed-joined-2022-04-30.dat.gz",
                         "fy22_checkouts")
e20220720 <- read_export("sierra-branch-healed-joined-2022-07-20.dat.gz",
                         "fy22_checkouts")
e20221028 <- read_export("sierra-all-healed-joined-2022-10-28.dat.gz",
                         "fy22_checkouts")
e20230710 <- read_export("sierra-all-healed-joined-2023-07-10.dat.gz",
                         "fy23_checkouts")
e20240108 <- read_export("sierra-all-healed-joined-2024-01-08.dat.gz",
                         "fy24_checkouts")
# this one is from just before the 2024 reset
e20240701 <- read_export("sierra-all-healed-joined-2024-07-01.dat.gz",
                         "fy24_checkouts")
# (only the total checkouts of these two are used)
e20250710 <- read_export("sierra-all-healed-joined-2025-07-10.dat.gz",
                         "fy25_checkouts")
e20260707 <- read_export(latestfile, "fy26_checkouts", dir=latestdir)

# there's no export from before the 2020 reset
at2020 <- e20210711[, .(itemid, atreset=total-ytd)]
at2021 <- lifetime_at_reset(e20211028, e20210711)
# no export from just before the 2022 reset has research items in it.
# a research item that the 2022 reset skipped can't be found, and its
# FY22 checkouts are counted in FY23
at2022 <- lifetime_at_reset(e20221028, e20220430, e20220720)
at2023 <- lifetime_at_reset(e20240108, e20230710)

at2021[, .N, skipped]
at2022[, .N, skipped]
at2023[, .N, skipped]

setnames(at2020, "atreset", "at2020reset")
setnames(at2021, "atreset", "at2021reset")
setnames(at2022, "atreset", "at2022reset")
setnames(at2023, "atreset", "at2023reset")

rm(e20210711)
rm(e20211028)
rm(e20220430)
rm(e20220720)
rm(e20221028)
rm(e20230710)
rm(e20240108)
gc()


# --------------------------------------------------------------- #

##########
####  FY21
####  (the reset in 2020 to the reset around 2021-07-30)

fy21 <- merge(at2021, at2020[, .(itemid, at2020reset)],
              by="itemid", all.x=TRUE)

# items in both exports
fy21[!is.na(at2020reset), newfy21:=at2021reset-at2020reset]

# items only in the later export. nearly all of them were created
# after 2021-07-11 so Sierra's last-year counter can be trusted
lastyear <- fread(sprintf("%s%s", archive,
                          "sierra-all-healed-joined-2021-10-28.dat.gz"),
                  select=c("itemid", "fy21_checkouts"))
lastyear <- lastyear[, .(lastyearcounter=max(fy21_checkouts)), itemid]
fy21[lastyear, on="itemid", lastyearcounter:=i.lastyearcounter]
fy21[is.na(at2020reset), newfy21:=lastyearcounter]

fy21[, .N, .(inboth=!is.na(at2020reset), rebuilt=!is.na(newfy21))]
fy21[newfy21<0, .N]
fy21[newfy21<0, newfy21:=0L]
fy21[, sum(newfy21, na.rm=TRUE)]

# items that aren't in the 2021-10-28 export keep what they have
# (they were all created later and have no value)
hist[fy21, on="itemid", fy21_checkouts:=i.newfy21]
# in this file, an item with no checkouts in a year is NA and not 0
hist[fy21_checkouts==0, fy21_checkouts:=NA]

rm(at2020)
rm(lastyear)
rm(fy21)
gc()


# --------------------------------------------------------------- #

##########
####  FY22
####  (the reset around 2021-07-30 to the reset around 2022-07-09)

fy22 <- merge(at2022, at2021[, .(itemid, at2021reset)],
              by="itemid", all.x=TRUE)

# items in both exports
fy22[!is.na(at2021reset), newfy22:=at2022reset-at2021reset]
# items created after the 2021 reset. all of their checkouts are FY22
fy22[is.na(at2021reset) & created_date>="2021-08", newfy22:=at2022reset]

fy22[, .N, .(inboth=!is.na(at2021reset), rebuilt=!is.na(newfy22))]
fy22[newfy22<0, .N]
fy22[newfy22<0, newfy22:=0L]
fy22[, sum(newfy22, na.rm=TRUE)]

# every value in the old column is a leftover from FY21
hist[, fy22_checkouts:=NA_integer_]
hist[fy22, on="itemid", fy22_checkouts:=i.newfy22]
hist[fy22_checkouts==0, fy22_checkouts:=NA]

rm(at2021)
rm(fy22)
gc()


# --------------------------------------------------------------- #

##########
####  FY23
####  (the reset around 2022-07-09 to the reset around 2023-07-15)

fy23 <- merge(at2023, at2022[, .(itemid, at2022reset)],
              by="itemid", all.x=TRUE)

# items in both exports
fy23[!is.na(at2022reset), newfy23:=at2023reset-at2022reset]
# items created after the 2022-10-28 export. all of their
# checkouts before the 2023 reset are FY23
fy23[is.na(at2022reset) & created_date>="2022-10-28", newfy23:=at2023reset]

fy23[, .N, .(inboth=!is.na(at2022reset), rebuilt=!is.na(newfy23))]
fy23[newfy23<0, .N]
fy23[newfy23<0, newfy23:=0L]
fy23[, sum(newfy23, na.rm=TRUE)]

# items that couldn't be rebuilt keep what they have
hist[fy23[!is.na(newfy23)], on="itemid", fy23_checkouts:=i.newfy23]
hist[fy23_checkouts==0, fy23_checkouts:=NA]

rm(at2022)
rm(fy23)
gc()


# --------------------------------------------------------------- #

##########
####  FY24
####  (the reset around 2023-07-15 to the export of 2024-07-01)

# the fy24 column of the historical circ file is the year-to-date
# counter in the 2024-07-01 export. That's right for most items. But
# for an item that the 2023 reset skipped, it has FY23 in it, too

fy24 <- merge(e20240701[, .(itemid, total)],
              at2023[, .(itemid, at2023reset)], by="itemid")

fy24[, newfy24:=total-at2023reset]

fy24[newfy24<0, .N]
fy24[newfy24<0, newfy24:=0L]
fy24[, sum(newfy24, na.rm=TRUE)]

# items that aren't in both exports keep what they have
# (nearly all of them were created after 2024-01-08)
hist[fy24, on="itemid", fy24_checkouts:=i.newfy24]
hist[fy24_checkouts==0, fy24_checkouts:=NA]

rm(at2023)
rm(fy24)
gc()


# --------------------------------------------------------------- #

##########
####  FY25
####  (the export of 2024-07-01 to the export of 2025-07-10)

fy25 <- merge(e20250710[, .(itemid, created_date, total)],
              e20240701[, .(itemid, totalbefore=total)],
              by="itemid", all.x=TRUE)

# items in both exports
fy25[!is.na(totalbefore), newfy25:=total-totalbefore]
# items created after the 2024-07-01 export. all of their
# checkouts are FY25
fy25[is.na(totalbefore) & created_date>="2024-07-01", newfy25:=total]

fy25[, .N, .(inboth=!is.na(totalbefore), built=!is.na(newfy25))]
fy25[newfy25<0, .N]
fy25[newfy25<0, newfy25:=0L]
fy25[, sum(newfy25, na.rm=TRUE)]

hist[, fy25_checkouts:=NA_integer_]
hist[fy25, on="itemid", fy25_checkouts:=i.newfy25]
hist[fy25_checkouts==0, fy25_checkouts:=NA]

rm(e20240701)
rm(fy25)
gc()


# --------------------------------------------------------------- #

##########
####  FY26
####  (the export of 2025-07-10 to the export of 2026-07-07)

fy26 <- merge(e20260707[, .(itemid, created_date, total)],
              e20250710[, .(itemid, totalbefore=total)],
              by="itemid", all.x=TRUE)

# items in both exports
fy26[!is.na(totalbefore), newfy26:=total-totalbefore]
# items created after the 2025-07-10 export. all of their
# checkouts are FY26
fy26[is.na(totalbefore) & created_date>="2025-07-10", newfy26:=total]

fy26[, .N, .(inboth=!is.na(totalbefore), built=!is.na(newfy26))]
fy26[newfy26<0, .N]
fy26[newfy26<0, newfy26:=0L]
fy26[, sum(newfy26, na.rm=TRUE)]

hist[, fy26_checkouts:=NA_integer_]
hist[fy26, on="itemid", fy26_checkouts:=i.newfy26]
hist[fy26_checkouts==0, fy26_checkouts:=NA]

rm(e20250710)
rm(fy26)
gc()


# --------------------------------------------------------------- #

#########################################
####  TOTAL CHECKOUTS IN THE LATEST EXPORT

# step 4 gets the current fiscal year by subtracting this
# from total checkouts
hist[e20260707, on="itemid", total_checkouts_at_last_july:=i.total]

hist[is.na(total_checkouts_at_last_july), .N]

rm(e20260707)
gc()


# --------------------------------------------------------------- #

hist %>% names
hist[,.N]
hist[, lapply(.SD, sum, na.rm=TRUE), .SDcols=patterns("^fy")]

## debugging
# this was a book about knots that
# I took out 2020-12
hist[bibid==11315077]
hist[itemid==14021710]

hist[bibid==20869063]     # :)


hist %>% fwrite(outfile)
