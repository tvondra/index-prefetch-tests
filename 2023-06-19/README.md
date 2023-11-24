# index prefetch tests

Scripts and results for index prefetch patch on PostgreSQL.

## benchmark scripts

- `run-i5.sh` script to run tests on my small (i5) machine
- `run-xeon.sh` script to run tests on my large (xeon) machine
- `run-btree.sh` - test point queries with btree index
- `run-hash.sh` - test point queries with hash index
- `run-btree-sort.sh` - test ORDER BY queries with btree index
- `run-btree-saop.sh` - test SAOP (array) queries with btree index


## utility scripts

- `drop-caches.sh` - drop data from page cache
- `load.sh` - load data into tables
- `create.sql` - schema definition, functions etc.


## raw results

- `i5` - raw results for the small machine
- `xeon` - raw results for the large machine


## processed results

- `csv` - preprocessed raw results
- `ods` - spreadsheet with summaries / pivot tables
- `pdf` - processed data with heatmap comparisons
- `patches` - benchmarked patches 


## patches

- `patch-v1` - original PoC patch
- `patch-v3` - PoC patch + prefetch LRU cache

