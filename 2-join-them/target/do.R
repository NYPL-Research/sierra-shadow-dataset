# RR



dat <- fread("./big-sierra-comb-2026-07-07.dat.gz")


dat <- dat[itype<=100]
dat <- dat[biblevel=="MONOGRAPH" & mattype=="BOOK/TEXT"]


dat %>% dt_counts_and_percents("biblevel")
dat %>% dt_counts_and_percents("mattype")

dat %>% names

dat %>% dt_counts_and_percents("research_collection")
dat %>% dt_counts_and_percents("aeon_indicator")

bkdat <- copy(dat)


dat <- dat[aeon_indicator==TRUE]

dat[,.N]
dat[,uniqueN(bibid)]
dat[,.N]
# 188,342


dat <- dat[!duplicated(bibid)]

dat %>% dt_counts_and_percents("research_collection")
dat[str_detect(research_collection, "^LPA ")] %>%
  dt_counts_and_percents("research_collection")

dat[str_detect(research_collection, "^LPA ")] %>%
  dt_counts_and_percents("research_collection")

dat[str_detect(research_collection, "^LPA ")][, uniqueN(bibid)]


dat[is.na(research_collection)] %>%
  dt_counts_and_percents("item_location_code")

dat[research_collection=="SASB - Dorot", .N]
dat[research_collection=="SASB - Dorot"] %>%
  dt_counts_and_percents("item_location_code")

dat[item_location_code=="maf88", .N]
dat[item_location_code=="maf88"] %>%
  dt_counts_and_percents("research_collection")





# RBK (SASB)
rbk.codes <- c("mar", "mar62", "mar82", "mar92", "mard2", "marr2", "qcmr2", "rcmr2")
rbk <- dat[item_location_code %chin% rbk.codes]
rbk[,.N]


# MARB (SCH)
sch.codes <- c("scd", "scdd1", "scdd2")
sch <- dat[item_location_code %chin% sch.codes]
sch[,.N]
sch[,uniqueN(bibid)]



# DOROT
dorot <- dat[item_location_code=="maf88"]
dorot[,.N]
dorot[,uniqueN(bibid)]


tmo <- bkdat[item_location_code=="maf88"]
tmo[, uniqueN(bibid)]


