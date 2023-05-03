
./run-hash.sh > hash.log 2>&1

./run-spgist.sh > spgist.log 2>&1

./run-gist.sh > gist.log 2>&1

./run-gist-distance.sh > gist-distance.log 2>&1

./run-spgist-distance.sh > spgist-distance.log 2>&1

./run-btree.sh > btree.log 2>&1

./run-btree-sort.sh > btree-sort.log 2>&1
