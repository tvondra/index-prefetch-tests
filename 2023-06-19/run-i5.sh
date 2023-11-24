#!/bin/bash -x

set -e

for rows in 1000000 10000000 50000000; do

	./run-btree.sh i5 /mnt/raid/pgdata $rows > btree-$rows.log 2>&1
	./run-hash.sh i5 /mnt/raid/pgdata $rows > hash-$rows.log 2>&1

done


for rows in 1000000 10000000 50000000; do

	./run-btree-sort.sh i5 /mnt/raid/pgdata $rows > btree-sort-$rows.log 2>&1
	./run-btree-saop.sh i5 /mnt/raid/pgdata $rows > btree-saop-$rows.log 2>&1

done
