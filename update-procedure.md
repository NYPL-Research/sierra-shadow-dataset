# nypl-shadow-export: the yearly fiscal-year update

Written 2026-11-17. This is for whoever does the update next July, on the
assumption that they remember nothing about how it works. That includes me.

All paths are relative to the root of the `nypl-shadow-export` repo.

---

## The one-minute version

Once a year, in July, in this order:

1. Make the first export after June 30 **exactly as usual. Do not change
   step 4 first.**
2. Run `making-new-historical-circ/update.R`. It writes next year's
   historical circ file.
3. Change step 4 in five places (new fiscal year).
4. Update four spots in the README.
5. Back up the new historical circ file. Commit.

The single most important rule: **the July export is made with step 4 still
set to the year that just ended.** If you bump step 4 before making it, the
numbers for the year that just ended are lost from that export.

---

## Why it works this way

Read this once. It makes every later step obvious.

- Sierra has a lifetime counter for each item, `total_checkouts`. It only
  ever goes up, and it is reliable.
- Sierra also has "this year" and "last year" counters. **The pipeline does
  not use them.** NYPL resets them on a different day each year (30 July in
  2021, 9 July in 2022, 15 July in 2023, 31 July in 2024, 7 July in 2025),
  and the reset skips some items. In 2023 it skipped 39% of the research
  items that had circulated. In 2022 it lost a whole year.
- So a fiscal year here is simply: **an item's `total_checkouts` in one
  July export, minus its `total_checkouts` in the July export before.**
- The historical circ file stores every finished year, plus one extra
  column, `total_checkouts_at_last_july`: each item's `total_checkouts` in
  the last July export.
- Step 4 computes the current year as
  `total_checkouts - total_checkouts_at_last_july`.

It follows that an export made in July already contains every fiscal year,
correctly, including the one that just ended. The yearly update is nothing
more than **saving that export's fiscal-year columns and its
`total_checkouts` as the new historical circ file**, and then telling step
4 that a new year has started.

"Fiscal years" therefore run from one July export to the next (for example
2025-07-10 to 2026-07-07), not exactly from July 1 to June 30.

---

## The files involved

| File | What it is |
|---|---|
| `4-add-historical-circ/add-historical-circ-and-subject-and-finish.R` | Step 4. Has five places that change each year. |
| `making-new-historical-circ/update.R` | The yearly script. Nothing in it needs editing. |
| `data/historical-circ/historical-circ-fy17-fyNN.dat.gz` | The historical circ file. `NN` is the last finished year. Not in git. |
| `target/sierra-all-healed-joined-YYYY-MM-DD.dat.gz` | The export that step 4 writes. Not in git. |
| `making-new-historical-circ/rebuild-fy21-to-fy24.R` | A one-off from November 2026. You should never need it. See the last section. |
| `README.md` | Four spots mention the years. |

To see where things stand right now:

```
ls data/historical-circ
grep -n 'lastjuly <-' 4-add-historical-circ/add-historical-circ-and-subject-and-finish.R
ls target
```

As of November 2026: the historical file is
`historical-circ-fy17-fy26.dat.gz`, `lastjuly` is `"2026-07-07"`, and the
current year in step 4 is FY27.

---

## The procedure

The examples are written for **July 2027**: FY27 has just ended and FY28 is
starting. For later years, add one to every year. An example export date of
`2027-07-08` is used throughout; use the real one.

### Step 1. Make the July export, changing nothing

Run the whole pipeline as for any other export: the dumps, step 1, step 2,
step 3, step 4.

- This must be the **first export after June 30**.
- **Do not edit step 4 before this.** It should still say `fy27_checkouts`.
- Step 4 lets an export dated up to July 31 through. That is on purpose.

When it finishes, `target/` should contain the new export:

```
target/sierra-all-healed-joined-2027-07-08.dat.gz
```

Its `fy27_checkouts` column is the complete FY27.

### Step 2. Make sure `target/` holds only that export

`update.R` looks for `target/sierra-all-healed-joined-*.dat.gz` and refuses
to guess if there is more than one.

```
ls target
```

If an older `sierra-all-healed-joined-...` file is still there, move it
somewhere else first. The `research` and `branch` files do not matter.

### Step 3. Run `update.R`

```
cd making-new-historical-circ
./update.R
```

There is nothing to edit in it. It works out the fiscal-year columns and
the output name from the export.

What to look for in what it prints:

| It prints | You want |
|---|---|
| `expdate` | The date of the July export, e.g. `2027-07-08` |
| `fycols` | `fy17_checkouts` through `fy27_checkouts` |
| `dat[is.na(total_checkouts_at_last_july), .N]` | `0` |
| The row of column sums | A believable number under `fy27_checkouts`, in the same range as the years before it |

It writes:

```
data/historical-circ/historical-circ-fy17-fy27.dat.gz
```

It never overwrites. The previous file,
`historical-circ-fy17-fy26.dat.gz`, is left alone. Keep it until the next
export has gone out cleanly.

### Step 4. Change step 4 in five places

File: `4-add-historical-circ/add-historical-circ-and-subject-and-finish.R`

Line numbers are as of November 2026 and will drift. Search for the text.

**Place 1: the guard date** (about line 44). Add one year.

```r
# before
if(as.Date(expdate) > as.Date("2027-07-31"))
# after
if(as.Date(expdate) > as.Date("2028-07-31"))
```

**Place 2: the historical circ file** (about line 47). Use the file
`update.R` just wrote.

```r
# before
old <- fread("../data/historical-circ/historical-circ-fy17-fy26.dat.gz")
# after
old <- fread("../data/historical-circ/historical-circ-fy17-fy27.dat.gz")
```

**Place 3: the current year** (about lines 98 to 117). Two things change
here.

First, `lastjuly` becomes the date of the July export you just made. It
must match the date in the export's file name.

```r
# before
lastjuly <- "2026-07-07"
# after
lastjuly <- "2027-07-08"
```

Second, the current-year column is **renamed** from `fy27_checkouts` to
`fy28_checkouts`. There are four occurrences on three lines:

```r
# before
comb[, fy27_checkouts:=total_checkouts-total_checkouts_at_last_july]
...
     fy27_checkouts:=total_checkouts]
...
comb[fy27_checkouts<=0, fy27_checkouts:=NA]

# after
comb[, fy28_checkouts:=total_checkouts-total_checkouts_at_last_july]
...
     fy28_checkouts:=total_checkouts]
...
comb[fy28_checkouts<=0, fy28_checkouts:=NA]
```

This is a rename, not an addition. From now on `fy27_checkouts` comes from
the historical circ file.

**Place 4: the two `bib_fy` sums** (about lines 180 and 309). **Add** a
line after the FY27 line in each. Keep the FY27 line.

```r
# first block (about line 180): add this line after the bib_fy27 line
         bib_fy28_checkouts         = sum(fy28_checkouts, na.rm=TRUE),

# second block (about line 309): add this line after the bib_fy27 line
             bib_fy28_checkouts           = sum(fy28_checkouts, na.rm=TRUE),
```

**Place 5: `finalorder`** (about lines 222 and 228). **Add** the two new
names. Keep the FY27 ones.

```r
# before
                "fy26_checkouts", "fy27_checkouts",
# after
                "fy26_checkouts", "fy27_checkouts", "fy28_checkouts",

# before
                "bib_fy27_checkouts",
# after
                "bib_fy27_checkouts", "bib_fy28_checkouts",
```

**Check the edit.** From the repo root:

```
grep -c 'fy28' 4-add-historical-circ/add-historical-circ-and-subject-and-finish.R
grep -c 'fy27_checkouts' 4-add-historical-circ/add-historical-circ-and-subject-and-finish.R
Rscript --vanilla -e 'invisible(parse("4-add-historical-circ/add-historical-circ-and-subject-and-finish.R")); cat("parses\n")'
```

The first should print `7`, the second `4`, and the third `parses`. If the
counts differ, a place was missed or something was renamed that should
have been added.

### Step 5. Update the README

Four spots in `README.md`:

1. **The historical circ file** (near the top, "a copy of the latest
   historical circ information"): `13 column` becomes `14 column`, and
   `FY17 to FY26` becomes `FY17 to FY27`.
2. **The Step 4 section, first paragraph**: `FY17 through FY26` becomes
   `FY17 through FY27`, `(FY27)` becomes `(FY28)`, and `eleven consecutive
   years` becomes `twelve`.
3. **The Step 4 table of dates**: the FY27 row's "to" changes from `the
   date of the export` to the July export's date, and a new last row is
   added.

   ```
   | `fy27_checkouts` | 2026-07-07 | 2027-07-08 |
   | `fy28_checkouts` | 2027-07-08 | the date of the export |
   ```

4. **The data dictionary**: add `fy28_checkouts` after `fy27_checkouts`,
   and `bib_fy28_checkouts` after `bib_fy27_checkouts`, in the same form
   as their neighbours.

### Step 6. Back up and commit

- Copy `data/historical-circ/historical-circ-fy17-fy27.dat.gz` to the
  shared drive. It is not in git, and without it the next export cannot be
  made.
- Keep the July export on the shared drive as well. The historical file
  can be remade from it (see "If the historical circ file is lost").
- Commit step 4 and the README.

### Step 7. The next export is the real test

The next export, any time before the following July, runs with the new
settings. In its output, check:

- `fy28_checkouts` has values, none negative, and its total is believable
  for the time since the July export.
- `fy27_checkouts` matches what the July export had.

Once that export is out, the previous historical file
(`historical-circ-fy17-fy26.dat.gz`) can go.

---

## Stop messages and what to do

| Message | Where | What it means | What to do |
|---|---|---|---|
| `new fiscal year. run ../making-new-historical-circ/update.R on the July export, then update this script` | Step 4 | The export is dated after July 31 and step 4 is still on last year. | If the July export was made: do steps 2 to 5 above, then rerun. If no export was made in July: see "No export was made in July". |
| `this export is older than the historical circ file. they can't be used together` | Step 4 | The export is dated before `lastjuly`. The historical circ file holds totals as of the last July export, so an older export can't be measured against it. | Use dumps taken after the last July export. If the dumps are right, `lastjuly` or the historical circ file is from the wrong year. |
| `argument specifying columns received non-existing column(s): ... 'fy28_checkouts'` (or similar) | Step 4, at `setcolorder` | A name in `finalorder` is not in the data. | One of the five places was missed, or step 4 is reading the old historical file (place 2). |
| `the export in ../target/ wasn't made in July` | `update.R` | The export's date is not in July. | Make sure the right export is in `target/`. If the year-end export really was not in July: see below. |
| `the newest fiscal year in the export isn't the one that just ended` | `update.R` | The newest `fyNN_checkouts` column does not match the export's year. | Step 4 was bumped before the July export was made, or this is last year's export. See "Step 4 was bumped too early". |
| `the output file already exists. I won't overwrite it` | `update.R` | It has already been run for this year. | Nothing, if the existing file is good. Otherwise move it aside and rerun. |
| `more than one matching file` | `update.R` or step 4 | Two dated files match in the folder it reads. | Move the older one out. |
| `no matching filename` | `update.R` or step 4 | The folder is empty of the file it wants. | For `update.R`: the July export is not in `target/`. |

---

## When it doesn't go to plan

### No export was made in July

The first export after June 30 is the year-end export, whatever month it
is in. If it is in August or later:

1. In step 4, temporarily change the guard date (place 1) to a date after
   the export, so this one run goes through with the old settings.
2. In `update.R`, comment out the two lines that stop when the export
   wasn't made in July.
3. Run `update.R`, then do steps 4 to 6 as normal. `lastjuly` is that
   export's date, even though it is not in July.
4. Put `update.R` back as it was.
5. In the README table, record the real date.

The fiscal year then simply runs to that date. Nothing is lost or counted
twice; the boundary just sits later.

### Two exports were made in July

Use the first one as the year-end export. Do the update. The second one is
then an ordinary export in the new fiscal year.

### Step 4 was bumped too early

If step 4 was changed to the new year before the July export was made, the
export has no column for the year that just ended.

Fix: undo the bump (`git checkout` or `git stash` the step 4 change), rerun
step 4 only (steps 1 to 3 do not need rerunning), then carry on from step
2 of the procedure.

### `update.R` was never run and a later export has already gone out

The later export will have been stopped by step 4's guard, so this should
not happen without someone overriding the guard. If it did: the July
export is still the source of truth. Put it in `target/` on its own, run
`update.R`, bump step 4, and remake the later export.

### If the historical circ file is lost

In order of preference:

1. Restore it from the shared drive.
2. Remake it from the last July export. Put that export in `target/` on
   its own and run `update.R`. This works because a July export contains
   everything the historical file does.
3. Only if both are gone: `rebuild-fy21-to-fy24.R`. See below.

---

## Do not

- **Do not bump step 4 before making the July export.**
- **Do not use Sierra's `this_year_circ` or `last_year_circ` for anything.**
  Step 4 drops them on purpose. They are still printed by the `compare()`
  calls near the top of step 4, which is fine as a sanity check.
- **Do not delete the previous historical circ file** until an export made
  with the new one has gone out.
- **Do not rename `total_checkouts_at_last_july`.** Step 4 looks for that
  exact name.
- **Do not worry about when NYPL resets Sierra's counters.** It no longer
  matters.

---

## About `rebuild-fy21-to-fy24.R`

In November 2026 the historical circ file turned out to be wrong for FY21
to FY24 (see `nypl-shadow-export-issues.md`, issues 39, 47 and 48). This
script rebuilt those years from archived exports, added FY25 and FY26, and
wrote `historical-circ-fy17-fy26.dat.gz`. Despite its name it builds the
whole file.

It was a one-off. It is kept as the record of how the file was made. To run
it again you would need all of these:

- `data/historical-circ/historical-circ-fy17-fy24.dat.gz` (the old file; it
  supplies FY17 to FY20, so **do not delete it**)
- `target/sierra-all-healed-joined-2026-07-07.dat.gz`
- In the folder named at the top of the script (`~/data/xfer/`), from the
  shared drive:
  - `sierra-all-healed-joined-2021-07-11--revision-1.dat.gz`
  - `sierra-all-healed-joined-2021-10-28.dat.gz`
  - `sierra-branch-healed-joined-2022-04-30.dat.gz`
  - `sierra-branch-healed-joined-2022-07-20.dat.gz`
  - `sierra-all-healed-joined-2022-10-28.dat.gz`
  - `sierra-all-healed-joined-2023-07-10.dat.gz`
  - `sierra-all-healed-joined-2024-01-08.dat.gz`
  - `sierra-all-healed-joined-2024-07-01.dat.gz`
  - `sierra-all-healed-joined-2025-07-10.dat.gz`

It takes about six minutes and refuses to overwrite its output. It only
gets you to the state of 2026-07-07; any year after that has to come from
that year's July export.

---

## What each column covers

| Column | From | To |
|---|---|---|
| `fy17_checkouts` to `fy20_checkouts` | | As Sierra's counters had them; never verified |
| `fy21_checkouts` | The reset in 2020 | About 2021-07-30 |
| `fy22_checkouts` | About 2021-07-30 | About 2022-07-09 |
| `fy23_checkouts` | About 2022-07-09 | About 2023-07-15 |
| `fy24_checkouts` | About 2023-07-15 | 2024-07-01 |
| `fy25_checkouts` | 2024-07-01 | 2025-07-10 |
| `fy26_checkouts` | 2025-07-10 | 2026-07-07 |
| `fy27_checkouts` | 2026-07-07 | The July 2027 export |

Add a row here each year, and in the README.

---

## What was and wasn't tested when this was set up

- The historical circ file was checked row by row against an independent
  calculation: 16,379,233 rows, no differences.
- Step 4 and `update.R` were run end to end on a 1-in-40 sample of real
  data (409,884 rows), not on a full export.
- The procedure above was rehearsed once on that sample: `update.R` wrote
  a file through FY27, the five edits were applied to a copy of step 4
  exactly as written here, the two `grep` counts came out as 7 and 4, and
  the edited copy ran and produced `fy28_checkouts` and
  `bib_fy28_checkouts` in the right place. The export dates in that
  rehearsal were pretend ones.
- As of 2026-11-17 the full pipeline had not yet been run with these
  changes. **The first full export after that date is the first real test
  of step 4, and July 2027 is the first real run of `update.R`.**
