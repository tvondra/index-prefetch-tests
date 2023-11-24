#!/bin/bash -x

set -e

PATH_OLD=$PATH

MACHINE=$1
DATADIR=$2
rows=$3

NRUNS=5

ts=`date +%Y%m%d-%H%M%S`
LOGFILE="btree-saop-$ts.log"
RESULTS="btree-saop-$ts.csv"

rm -f $LOGFILE $RESULTS

echo "test machine time rows dataset matches distinct build nvalues distance prefetch table_size index_size scan_type caching run value nfound cost duration" > $RESULTS

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

				# how many values to have in the IN list
				for nvalues in 5 10 100; do

					# how far apart should the values be (sequential or skip some)
					for distance in 1 10; do

						# make sure we can generate a sequence with valid values
						x=$((distinct - (nvalues * distance)))
						if [ "$x" -lt "1" ]; then
							continue
						fi

						# how far we prefetch
						for prefetch in 0 32; do

							pg_ctl -D $DATADIR -l pg.log -w restart >> $LOGFILE 2>&1

							# now run queries with different parameters, forcing different types of plans
							for r in `seq 1 $NRUNS`; do

								for scan in indexonlyscan indexscan bitmapscan seqscan; do

									# with an index only scans, we remove the visibility map (bit harsh)
									# otherwise do vacuum, to build the VM
									if [ "$scan" == "indexonlyscan" ]; then
										dboid=`psql -t -A test -c "select oid from pg_database where datname = 'test'"`
										relfile=`psql -t -A test -c "select relfilenode from pg_class where relname = 'btree_test'"`
										rm $DATADIR/base/$dboid/${relfile}_vm >> $LOGFILE 2>&1
										query="select a from btree_test where a IN ($values)"
									else
										psql -t -A test -c "vacuum btree_test" >> $LOGFILE 2>&1
										query="select * from btree_test where a IN ($values)"
									fi

									# with seqscan we do only one run to save time
									if [ "$scan" == "seqscan" ]; then
										if [ "$r" -gt "1" ]; then
											continue
										fi
									fi

									# UNCACHED

									time=`date +%s`

									echo "======================== $time $rows $dataset distinct $distinct matches $matches build $build values $nvalues distance $distance prefetch $prefetch run $r $scan / uncached ========================" >> $LOGFILE 2>&1

									# restart to clean postgres cache, then drop OS caches
									pg_ctl -D $DATADIR -l pg.log -w restart >> $LOGFILE 2>&1
									sudo ./drop-caches.sh >> $LOGFILE 2>&1

									# random value to search for in the table
									value=`psql test -t -A -c "select ((($r - 1) * 1.0 / $NRUNS + (1.0 / $NRUNS) * random()) * ($distinct - $nvalues * $distance))::int"`

									values="$value"
									for i in `seq 1 $((nvalues-1))`; do
										values="$values,$((value + i * distance))"
									done

									psql test > explain.log 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = off;
set enable_seqscan = off;
set enable_$scan = on;
set max_parallel_workers_per_gather = 0;
set effective_io_concurrency = $prefetch;
explain $query;
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
$query;
EOF

									duration=`psql test -t -A -c "select (extract(epoch from now()) - $start) * 1000"`

									# number of rows returned by the query
									nfound=`grep -v SET tmp.log | wc -l | awk '{print $1}'`

									echo "btree-saop" $MACHINE $time $rows $dataset $matches $distinct $build $nvalues $distance $prefetch $ts $is $scan uncached $r $value $nfound $cost $duration >> $RESULTS 2>&1


									# CACHED

									time=`date +%s`

									echo "======================== $time $rows $dataset distinct $distinct matches $matches build $build values $nvalues distance $distance prefetch $prefetch run $r $scan / cached ========================" >> $LOGFILE 2>&1

									psql test > explain.log 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = off;
set enable_seqscan = off;
set enable_$scan = on;
set max_parallel_workers_per_gather = 0;
set effective_io_concurrency = $prefetch;
explain $query;
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
$query;
EOF

									duration=`psql test -t -A -c "select (extract(epoch from now()) - $start) * 1000"`

									# number of rows returned by the query
									nfound=`grep -v SET tmp.log | wc -l | awk '{print $1}'`

									echo "btree-saop" $MACHINE $time $rows $dataset $matches $distinct $build $nvalues $distance $prefetch $ts $is $scan cached $r $value $nfound $cost $duration >> $RESULTS 2>&1

								done

							done

						done

					done

				done

			done

		done

	done

# done

psql test -c "drop table if exists btree_test" >> $LOGFILE 2>&1
