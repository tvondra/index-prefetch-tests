#!/bin/bash -x

set -e

PATH_OLD=$PATH

MACHINE=$1
DATADIR=$2
rows=$3

NRUNS=5

ts=`date +%Y%m%d-%H%M%S`
LOGFILE="btree-$ts.log"
RESULTS="btree-$ts.csv"

rm -f $LOGFILE $RESULTS

echo "test machine time rows dataset matches distinct build prefetch table_size index_size scan_type caching run value nfound cost duration" > $RESULTS

# btree

# number of rows in the table
# for rows in 1000000 10000000 100000000 500000000; do

	# pattern in the data set
	for dataset in random cycle sequential; do

		# number of matches for each value
		for matches in 1000 10 10000 100 1 100000; do

			# number of distinct values in the column
			distinct=$((rows/matches))

			PATH=$HOME/builds/pg-master/bin:$PATH_OLD

			psql test -c "drop table if exists btree_test" >> $LOGFILE 2>&1
			psql test -c "create table btree_test (a int, b text) with (fillfactor=20)" >> $LOGFILE 2>&1

			if [ "$dataset" == "random" ]; then
				# random data
				psql test -c "insert into btree_test select $distinct * random(), md5(i::text) from generate_series(1, $rows) s(i)" >> $LOGFILE 2>&1
			elif [ "$dataset" == "cycle" ]; then
				# cycling values 1, 2, ..., d, 1, 2, ..., d, ...
				psql test -c "insert into btree_test select 1 + mod(i, $distinct), md5(i::text) from generate_series(1, $rows) s(i)" >> $LOGFILE 2>&1
			elif [ "$dataset" == "sequential" ]; then
				# continuous runs of values 1, 1, ..., 1, 2, 2, ..., 2, ..., d, d, ..., d
				psql test -c "insert into btree_test select 1 + ((i - 1) / $matches), md5(i::text) from generate_series(1, $rows) s(i)" >> $LOGFILE 2>&1
			fi;

			psql test -c "create index btree_test_idx on btree_test using btree (a)" >> $LOGFILE 2>&1
			psql test -c "vacuum analyze" >> $LOGFILE 2>&1
			psql test -c "checkpoint" >> $LOGFILE 2>&1

			psql test -c "\d+" >> $LOGFILE 2>&1
			psql test -c "\di+" >> $LOGFILE 2>&1

			# get table / index size
			ts=`psql test -A -t -c "select relpages from pg_class where relname = 'btree_test'"`
			is=`psql test -A -t -c "select relpages from pg_class where relname = 'btree_test_idx'"`

			# which build to use
			for build in master patched; do

				PATH=$HOME/builds/pg-$build/bin:$PATH_OLD

				# restart using the proper build (can't do restart)
				pg_ctl -D $DATADIR -l pg.log -w stop >> $LOGFILE 2>&1
				pg_ctl -D $DATADIR -l pg.log -w start >> $LOGFILE 2>&1

				# how far we prefetch
				for prefetch in 0 32; do

					pg_ctl -D $DATADIR -l pg.log -w restart >> $LOGFILE 2>&1

					# now run queries with different parameters, forcing different types of plans
					for r in `seq 1 $NRUNS`; do

						for scan in indexscan bitmapscan seqscan; do

							# with seqscan we do only one run to save time
							if [ "$scan" == "seqscan" ]; then
								if [ "$r" -gt "1" ]; then
									continue
								fi
							fi

							# UNCACHED

							time=`date +%s`

							echo "======================== $time $rows $dataset $matches $distinct $build $prefetch $r $scan / uncached ========================" >> $LOGFILE 2>&1

							# restart to clean postgres cache, then drop OS caches
							pg_ctl -D $DATADIR -l pg.log -w restart >> $LOGFILE 2>&1
							sudo ./drop-caches.sh >> $LOGFILE 2>&1

							# random value to search for in the table
							value=`psql test -t -A -c "select ((($r - 1) * 1.0 / $NRUNS + (1.0 / $NRUNS) * random()) * $distinct)::int"`

							psql test > explain.log 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = off;
set enable_seqscan = off;
set enable_$scan = on;
set max_parallel_workers_per_gather = 0;
set effective_io_concurrency = $prefetch;
explain select * from btree_test where a = $value;
EOF

							cat explain.log >> $LOGFILE
							cost=`grep cost explain.log | head -n 1 | sed 's/.*cost=//' | sed 's/ rows.*//' | sed 's/.*\.\.//'`

							start=`psql test -t -A -c 'select extract(epoch from now())'`

							psql -t -A test > tmp.log 2>&1 <<EOF
select set_taskset(3);
set enable_bitmapscan = off;
set enable_indexscan = off;
set enable_seqscan = off;
set enable_$scan = on;
set max_parallel_workers_per_gather = 0;
set effective_io_concurrency = $prefetch;
select * from btree_test where a = $value;
EOF

							duration=`psql test -t -A -c "select (extract(epoch from now()) - $start) * 1000"`

							# number of rows returned by the query
							nfound=`grep -v SET tmp.log | wc -l | awk '{print $1}'`

							echo "btree" $MACHINE $time $rows $dataset $matches $distinct $build $prefetch $ts $is $scan uncached $r $value $nfound $cost $duration >> $RESULTS 2>&1


							# CACHED

							time=`date +%s`

							echo "======================== $time $rows $dataset $matches $distinct $build $prefetch $r $scan / cached ========================" >> $LOGFILE 2>&1

							psql test > explain.log 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = off;
set enable_seqscan = off;
set enable_$scan = on;
set max_parallel_workers_per_gather = 0;
set effective_io_concurrency = $prefetch;
explain select * from btree_test where a = $value;
EOF

							cat explain.log >> $LOGFILE
							cost=`grep cost explain.log | head -n 1 | sed 's/.*cost=//' | sed 's/ rows.*//' | sed 's/.*\.\.//'`

							start=`psql test -t -A -c 'select extract(epoch from now())'`

							psql -t -A test > tmp.log 2>&1 <<EOF
select set_taskset(3);
set enable_bitmapscan = off;
set enable_indexscan = off;
set enable_seqscan = off;
set enable_$scan = on;
set max_parallel_workers_per_gather = 0;
set effective_io_concurrency = $prefetch;
select * from btree_test where a = $value;
EOF

							duration=`psql test -t -A -c "select (extract(epoch from now()) - $start) * 1000"`

							# number of rows returned by the query
							nfound=`grep -v SET tmp.log | wc -l | awk '{print $1}'`

							echo "btree" $MACHINE $time $rows $dataset $matches $distinct $build $prefetch $ts $is $scan cached $r $value $nfound $cost $duration >> $RESULTS 2>&1

						done

					done

				done

			done

		done

	done

# done

psql test -c "drop table if exists btree_test" >> $LOGFILE 2>&1

