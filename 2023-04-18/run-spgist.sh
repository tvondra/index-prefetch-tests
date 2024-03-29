#!/bin/bash -x

set -e

PATH_OLD=$PATH
DATADIR=/mnt/raid/pgdata

#ROWS=50000000
ROWS=1000000
DISTINCT=100000

ts=`date +%Y%m%d-%H%M%S`
LOGFILE="spgist-$ts.log"
RESULTS="spgist-$ts.csv"

rm -f $LOGFILE $RESULTS

# SPGIST

PATH=$HOME/pg-master/bin:$PATH_OLD
# pg_ctl -D $DATADIR -l pg.log -w stop >> $LOGFILE 2>&1
pg_ctl -D $DATADIR -l pg.log -w restart >> $LOGFILE 2>&1

d=$((DISTINCT))

psql test -c "drop table if exists spgist_test" >> $LOGFILE 2>&1
psql test -c "create table spgist_test (a point, b text) with (fillfactor=20)" >> $LOGFILE 2>&1
psql test -c "insert into spgist_test select format('(%s,%s)', x1, y1)::point, md5(random()::text) from (select ($d * random())::int as x1, ($d * random())::int as y1 from generate_series(1, $ROWS) s(i)) foo" >> $LOGFILE 2>&1
psql test -c "create index on spgist_test using spgist (a)" >> $LOGFILE 2>&1
psql test -c "vacuum analyze" >> $LOGFILE 2>&1
psql test -c "checkpoint" >> $LOGFILE 2>&1

for n in 1000 10 10000 100 1 100000; do

	for r in `seq 1 10`; do

		t=`date +%s`

		echo "======================== master $t ========================" >> $LOGFILE 2>&1

		PATH=$HOME/pg-master/bin:$PATH_OLD

		pg_ctl -D $DATADIR -l pg.log -w stop >> $LOGFILE 2>&1
		pg_ctl -D $DATADIR -l pg.log -w start >> $LOGFILE 2>&1

		sudo ./drop-caches.sh >> $LOGFILE 2>&1

		delta=`psql test -t -A -c "select (1 + $d * sqrt($n::real / $ROWS))::int"`

		x1=`psql test -t -A -c "select (random() * $d)::int"`
		x2=`psql test -t -A -c "select (random() * $d)::int"`
		y1=$((x1 + delta))
		y2=$((x2 + delta))

		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test > tmp.log 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = on;
set enable_seqscan = off;
explain select * from spgist_test where a <@ '($x1,$x2),($y1,$y2)'::box;
select * from spgist_test where a <@ '($x1,$x2),($y1,$y2)'::box;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		q=`grep rows tmp.log | tail -n 1 | awk '{print $1}' | sed 's/(//'`
		cat tmp.log >> $LOGFILE

		echo "spgist" $r $n $q $x1 $x2 $y1 $y2 master uncached $e >> $RESULTS 2>&1


		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test > tmp.log 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = on;
set enable_seqscan = off;
explain select * from spgist_test where a <@ '($x1,$x2),($y1,$y2)'::box;
select * from spgist_test where a <@ '($x1,$x2),($y1,$y2)'::box;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		q=`grep rows tmp.log | tail -n 1 | awk '{print $1}' | sed 's/(//'`
		cat tmp.log >> $LOGFILE

		echo "spgist" $r $n $q $x1 $x2 $y1 $y2 master cached $e >> $RESULTS 2>&1

	done

	for r in `seq 1 10`; do

		t=`date +%s`

		echo "======================== patched $t ========================" >> $LOGFILE 2>&1

		PATH=$HOME/pg-patched/bin:$PATH_OLD

		pg_ctl -D $DATADIR -l pg.log -w stop >> $LOGFILE 2>&1
		pg_ctl -D $DATADIR -l pg.log -w start >> $LOGFILE 2>&1

		sudo ./drop-caches.sh >> $LOGFILE 2>&1

		delta=`psql test -t -A -c "select (1 + $d * sqrt($n::real / $ROWS))::int"`

		x1=`psql test -t -A -c "select (random() * $d)::int"`
		x2=`psql test -t -A -c "select (random() * $d)::int"`
		y1=$((x1 + delta))
		y2=$((x2 + delta))

		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test > tmp.log 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = on;
set enable_seqscan = off;
explain select * from spgist_test where a <@ '($x1,$x2),($y1,$y2)'::box;
select * from spgist_test where a <@ '($x1,$x2),($y1,$y2)'::box;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		q=`grep rows tmp.log | tail -n 1 | awk '{print $1}' | sed 's/(//'`
		cat tmp.log >> $LOGFILE

		echo "spgist" $r $n $q $x1 $x2 $y1 $y2 patched uncached $e >> $RESULTS 2>&1


		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test > tmp.log 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = on;
set enable_seqscan = off;
explain select * from spgist_test where a <@ '($x1,$x2),($y1,$y2)'::box;
select * from spgist_test where a <@ '($x1,$x2),($y1,$y2)'::box;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		q=`grep rows tmp.log | tail -n 1 | awk '{print $1}' | sed 's/(//'`
		cat tmp.log >> $LOGFILE

		echo "spgist" $r $n $q $x1 $x2 $y1 $y2 patched cached $e >> $RESULTS 2>&1

	done

	for r in `seq 1 10`; do

		t=`date +%s`

		echo "======================== bitmapscan $t ========================" >> $LOGFILE 2>&1

		PATH=$HOME/pg-master/bin:$PATH_OLD

		pg_ctl -D $DATADIR -l pg.log -w stop >> $LOGFILE 2>&1
		pg_ctl -D $DATADIR -l pg.log -w start >> $LOGFILE 2>&1

		sudo ./drop-caches.sh >> $LOGFILE 2>&1

		delta=`psql test -t -A -c "select (1 + $d * sqrt($n::real / $ROWS))::int"`

		x1=`psql test -t -A -c "select (random() * $d)::int"`
		x2=`psql test -t -A -c "select (random() * $d)::int"`
		y1=$((x1 + delta))
		y2=$((x2 + delta))

		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test > tmp.log 2>&1 <<EOF
set enable_bitmapscan = on;
set enable_indexscan = off;
set enable_seqscan = off;
explain select * from spgist_test where a <@ '($x1,$x2),($y1,$y2)'::box;
select * from spgist_test where a <@ '($x1,$x2),($y1,$y2)'::box;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		q=`grep rows tmp.log | tail -n 1 | awk '{print $1}' | sed 's/(//'`
		cat tmp.log >> $LOGFILE

		echo "spgist" $r $n $q $x1 $x2 $y1 $y2 bitmapscan uncached $e >> $RESULTS 2>&1


		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test > tmp.log 2>&1 <<EOF
set enable_bitmapscan = on;
set enable_indexscan = off;
set enable_seqscan = off;
explain select * from spgist_test where a <@ '($x1,$x2),($y1,$y2)'::box;
select * from spgist_test where a <@ '($x1,$x2),($y1,$y2)'::box;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		q=`grep rows tmp.log | tail -n 1 | awk '{print $1}' | sed 's/(//'`
		cat tmp.log >> $LOGFILE

		echo "spgist" $r $n $q $x1 $x2 $y1 $y2 bitmapscan cached $e >> $RESULTS 2>&1

	done


	for r in `seq 1 10`; do

		t=`date +%s`

		echo "======================== seqscan $t ========================" >> $LOGFILE 2>&1

		PATH=$HOME/pg-master/bin:$PATH_OLD

		pg_ctl -D $DATADIR -l pg.log -w stop >> $LOGFILE 2>&1
		pg_ctl -D $DATADIR -l pg.log -w start >> $LOGFILE 2>&1

		sudo ./drop-caches.sh >> $LOGFILE 2>&1

		delta=`psql test -t -A -c "select (1 + $d * sqrt($n::real / $ROWS))::int"`

		x1=`psql test -t -A -c "select (random() * $d)::int"`
		x2=`psql test -t -A -c "select (random() * $d)::int"`
		y1=$((x1 + delta))
		y2=$((x2 + delta))

		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test > tmp.log 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = off;
set enable_seqscan = on;
explain select * from spgist_test where a <@ '($x1,$x2),($y1,$y2)'::box;
select * from spgist_test where a <@ '($x1,$x2),($y1,$y2)'::box;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		q=`grep rows tmp.log | tail -n 1 | awk '{print $1}' | sed 's/(//'`
		cat tmp.log >> $LOGFILE

		echo "spgist" $r $n $q $x1 $x2 $y1 $y2 seqscan uncached $e >> $RESULTS 2>&1


		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test > tmp.log 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = off;
set enable_seqscan = on;
explain select * from spgist_test where a <@ '($x1,$x2),($y1,$y2)'::box;
select * from spgist_test where a <@ '($x1,$x2),($y1,$y2)'::box;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		q=`grep rows tmp.log | tail -n 1 | awk '{print $1}' | sed 's/(//'`
		cat tmp.log >> $LOGFILE

		echo "spgist" $r $n $q $x1 $x2 $y1 $y2 seqscan cached $e >> $RESULTS 2>&1

	done

done
