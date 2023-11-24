#!/bin/bash -x

set -e

DATADIR=$1

for rows in 1000000 10000000 50000000; do

	./run-btree.sh vostro $DATADIR $rows > btree-$rows.log 2>&1
	./run-hash.sh vostro $DATADIR $rows > hash-$rows.log 2>&1

done


for rows in 1000000 10000000 50000000; do

	./run-btree-sort.sh vostro $DATADIR $rows > btree-sort-$rows.log 2>&1
	./run-btree-saop.sh vostro $DATADIR $rows > btree-saop-$rows.log 2>&1

done
