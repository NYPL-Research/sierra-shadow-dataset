#!/bin/bash

set -e
set -u
set -o pipefail
set -x

GEN_LOCATION="$HOME/data/nypl-sql-dumps/"
EXPDATE=$(ls "$GEN_LOCATION" | sort | tail -n 1)
EXACT_LOCATION="$GEN_LOCATION$EXPDATE"

BIB_PATH=$(ls "$EXACT_LOCATION" | grep bib)
BIB_PATH="$EXACT_LOCATION/$BIB_PATH"
ITEM_PATH=$(ls "$EXACT_LOCATION" | grep item)
ITEM_PATH="$EXACT_LOCATION/$ITEM_PATH"

[ -f "$BIB_PATH" ]  || { echo "no single bib dump in $EXACT_LOCATION" >&2; exit 1; }
[ -f "$ITEM_PATH" ] || { echo "no single item dump in $EXACT_LOCATION" >&2; exit 1; }

echo "-> $BIB_PATH"
echo "-> $ITEM_PATH"
echo "-> $EXPDATE"

# BIBS
zcat "$BIB_PATH" | ./bibs/export-bib-info-first-step.py
pigz exported-bibs-raw-from-python.dat
mv exported-bibs-raw-from-python.dat.gz "./bibs/exported-bibs-raw-from-python-$EXPDATE.dat.gz"

# ITEMS
zcat "$ITEM_PATH" | ./items/export-item-info-first-step.py
pigz exported-items-raw-from-python.dat
mv exported-items-raw-from-python.dat.gz "./items/exported-items-raw-from-python-$EXPDATE.dat.gz"


