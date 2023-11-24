#!/bin/bash -x

set -e

PATH_OLD=$PATH
DATADIR=$HOME/tmp/data-master

#ROWS=50000000
ROWS=1000000
DISTINCT=100000

ts=`date +%Y%m%d-%H%M%S`
LOGFILE="gist-distance-$ts.log"
RESULTS="gist-distance-$ts.csv"

rm -f $LOGFILE $RESULTS

PATH=$HOME/pg-master/bin:$PATH_OLD
# pg_ctl -D $DATADIR -l pg.log -w stop >> $LOGFILE 2>&1
pg_ctl -D $DATADIR -l pg.log -w restart >> $LOGFILE 2>&1

d=$((DISTINCT))

psql test -e -c "drop table if exists gist_test" >> $LOGFILE 2>&1
psql test -e -c "create table gist_test (a point, b text) with (fillfactor=20)" >> $LOGFILE 2>&1
psql test -e -c "insert into gist_test select format('(%s,%s)', x, y)::point, md5(random()::text) from (select ($d * random())::int as x, ($d * random())::int as y from generate_series(1,$ROWS) s(i)) foo" >> $LOGFILE 2>&1
psql test -e -c "create index on gist_test using gist (a)" >> $LOGFILE 2>&1
psql test -e -c "vacuum analyze" >> $LOGFILE 2>&1
psql test -e -c "checkpoint" >> $LOGFILE 2>&1


for n in 1000 10 10000 100 1 100000; do

	for r in `seq 1 10`; do

		t=`date +%s`

		echo "======================== master $t ========================" >> $LOGFILE 2>&1

		PATH=$HOME/pg-master/bin:$PATH_OLD

		pg_ctl -D $DATADIR -l pg.log -w stop >> $LOGFILE 2>&1
		pg_ctl -D $DATADIR -l pg.log -w start >> $LOGFILE 2>&1

		sudo ./drop-caches.sh >> $LOGFILE 2>&1

		x=`psql test -t -A -c "select (random() * $d)::int"`
		y=`psql test -t -A -c "select (random() * $d)::int"`

		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test -e >> $LOGFILE 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = on;
set enable_seqscan = off;
explain select * from gist_test order by a <-> '($x,$y)'::point limit $n;
select * from gist_test order by a <-> '($x,$y)'::point limit $n;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		echo "gist" $t $r $n $x $y master uncached $e >> $RESULTS 2>&1


		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test -e >> $LOGFILE 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = on;
set enable_seqscan = off;
explain select * from gist_test order by a <-> '($x,$y)'::point limit $n;
select * from gist_test order by a <-> '($x,$y)'::point limit $n;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		echo "gist" $t $r $n $x $y master cached $e >> $RESULTS 2>&1

	done

	for r in `seq 1 10`; do

		t=`date +%s`

		echo "======================== patched $t ========================" >> $LOGFILE 2>&1

		PATH=$HOME/pg-patched/bin:$PATH_OLD

		pg_ctl -D $DATADIR -l pg.log -w stop >> $LOGFILE 2>&1
		pg_ctl -D $DATADIR -l pg.log -w start >> $LOGFILE 2>&1

		sudo ./drop-caches.sh >> $LOGFILE 2>&1

		delta=`psql test -t -A -c "select (1 + $d * sqrt($n::real / $ROWS))::int"`

		x=`psql test -t -A -c "select (random() * $d)::int"`
		y=`psql test -t -A -c "select (random() * $d)::int"`

		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test -e >> $LOGFILE 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = on;
set enable_seqscan = off;
explain select * from gist_test order by a <-> '($x,$y)'::point limit $n;
select * from gist_test order by a <-> '($x,$y)'::point limit $n;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		echo "gist" $t $r $n $x $y patched uncached $e >> $RESULTS 2>&1


		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test -e >> $LOGFILE 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = on;
set enable_seqscan = off;
explain select * from gist_test order by a <-> '($x,$y)'::point limit $n;
select * from gist_test order by a <-> '($x,$y)'::point limit $n;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		echo "gist" $t $r $n $x $y patched cached $e >> $RESULTS 2>&1

	done

	# no point in trying bitmap scans for distance queries

	for r in `seq 1 10`; do

		t=`date +%s`

		echo "======================== seqscan $t ========================" >> $LOGFILE 2>&1

		PATH=$HOME/pg-master/bin:$PATH_OLD

		pg_ctl -D $DATADIR -l pg.log -w stop >> $LOGFILE 2>&1
		pg_ctl -D $DATADIR -l pg.log -w start >> $LOGFILE 2>&1

		sudo ./drop-caches.sh >> $LOGFILE 2>&1

		delta=`psql test -t -A -c "select (1 + $d * sqrt($n::real / $ROWS))::int"`

		x=`psql test -t -A -c "select (random() * $d)::int"`
		y=`psql test -t -A -c "select (random() * $d)::int"`

		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test -e >> $LOGFILE 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = off;
set enable_seqscan = on;
explain select * from gist_test order by a <-> '($x,$y)'::point limit $n;
select * from gist_test order by a <-> '($x,$y)'::point limit $n;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		echo "gist" $t $r $n $x $y seqscan uncached $e >> $RESULTS 2>&1


		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test -e >> $LOGFILE 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = off;
set enable_seqscan = on;
explain select * from gist_test order by a <-> '($x,$y)'::point limit $n;
select * from gist_test order by a <-> '($x,$y)'::point limit $n;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		echo "gist" $t $r $n $x $y seqscan cached $e >> $RESULTS 2>&1

	done

done
