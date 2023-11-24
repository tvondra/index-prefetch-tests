#!/bin/bash -x

set -e

for rows in 1000000 10000000 100000000; do

        ./run-btree.sh xeon /mnt/data/pgdata $rows > btree-$rows.log 2>&1
        ./run-hash.sh xeon /mnt/data/pgdata $rows > hash-$rows.log 2>&1

done


for rows in 1000000 10000000 100000000; do

	./run-btree-sort.sh xeon /mnt/data/pgdata $rows > btree-sort-$rows.log 2>&1
	./run-btree-saop.sh xeon /mnt/data/pgdata $rows > btree-saop-$rows.log 2>&1

done
