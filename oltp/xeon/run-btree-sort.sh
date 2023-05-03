#!/bin/bash -x

set -e

PATH_OLD=$PATH
DATADIR=/mnt/data/pgdata

ROWS=500000000
#ROWS=25000000
DISTINCT=100000

ts=`date +%Y%m%d-%H%M%S`
LOGFILE="btree-sort-$ts.log"
RESULTS="btree-sort-$ts.csv"

rm -f $LOGFILE $RESULTS

# BTREE ordered

for n in 1000 10 10000 100 1 100000; do

	PATH=$HOME/pg-master/bin:$PATH_OLD
	# pg_ctl -D $DATADIR -l pg.log -w stop >> $LOGFILE 2>&1
	pg_ctl -D $DATADIR -l pg.log -w restart >> $LOGFILE 2>&1

	d=$((ROWS/n))

	psql test -c "drop table if exists btree_test" >> $LOGFILE 2>&1
	psql test -c "create table btree_test (a int, b text) with (fillfactor=20)" >> $LOGFILE 2>&1
	psql test -c "insert into btree_test select $d * random(), md5(i::text) from generate_series(1, $ROWS) s(i)" >> $LOGFILE 2>&1
	psql test -c "create index on btree_test using btree (a)" >> $LOGFILE 2>&1
	psql test -c "vacuum analyze" >> $LOGFILE 2>&1
	psql test -c "checkpoint" >> $LOGFILE 2>&1

	psql test -c "\d+" >> $LOGFILE 2>&1
	psql test -c "\di+" >> $LOGFILE 2>&1

	for r in `seq 1 10`; do

		t=`date +%s`

		echo "======================== master $t ========================" >> $LOGFILE 2>&1

		PATH=$HOME/pg-master/bin:$PATH_OLD

		pg_ctl -D $DATADIR -l pg.log -w stop >> $LOGFILE 2>&1
		pg_ctl -D $DATADIR -l pg.log -w start >> $LOGFILE 2>&1

		sudo ./drop-caches.sh >> $LOGFILE 2>&1

		v=`psql test -t -A -c "select (random() * $d)::int"`

		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test > tmp.log 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = on;
set enable_seqscan = off;
explain select * from btree_test where a >= $v order by a limit $n;
select * from btree_test where a >= $v order by a limit $n;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		q=`grep row tmp.log | tail -n 1 | awk '{print $1}' | sed 's/(//'`
		cat tmp.log >> $LOGFILE

		echo "btree-sort" $t $r $n $q master uncached $e $v >> $RESULTS 2>&1


		t=`date +%s`

		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test >> $LOGFILE 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = on;
set enable_seqscan = off;
explain select * from btree_test where a >= $v order by a limit $n;
select * from btree_test where a >= $v order by a limit $n;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		echo "btree-sort" $t $r $n $q master cached $e $v >> $RESULTS 2>&1

	done

	for r in `seq 1 10`; do

		t=`date +%s`

		echo "======================== patched $t ========================" >> $LOGFILE 2>&1

		PATH=$HOME/pg-patched/bin:$PATH_OLD

		pg_ctl -D $DATADIR -l pg.log -w stop >> $LOGFILE 2>&1
		pg_ctl -D $DATADIR -l pg.log -w start >> $LOGFILE 2>&1

		sudo ./drop-caches.sh >> $LOGFILE 2>&1

		v=`psql test -t -A -c "select (random() * $d)::int"`

		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test > tmp.log 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = on;
set enable_seqscan = off;
explain select * from btree_test where a >= $v order by a limit $n;
select * from btree_test where a >= $v order by a limit $n;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		q=`grep row tmp.log | tail -n 1 | awk '{print $1}' | sed 's/(//'`
		cat tmp.log >> $LOGFILE

		echo "btree-sort" $t $r $n $q patched uncached $e $v >> $RESULTS 2>&1


		t=`date +%s`

		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test >> $LOGFILE 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = on;
set enable_seqscan = off;
explain select * from btree_test where a >= $v order by a limit $n;
select * from btree_test where a >= $v order by a limit $n;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		echo "btree-sort" $t $r $n $q patched cached $e $v >> $RESULTS 2>&1

	done

	for r in `seq 1 10`; do

		t=`date +%s`

		echo "======================== bitmapscan $t ========================" >> $LOGFILE 2>&1


		PATH=$HOME/pg-master/bin:$PATH_OLD

		pg_ctl -D $DATADIR -l pg.log -w stop >> $LOGFILE 2>&1
		pg_ctl -D $DATADIR -l pg.log -w start >> $LOGFILE 2>&1

		sudo ./drop-caches.sh >> $LOGFILE 2>&1

		v=`psql test -t -A -c "select (random() * $d)::int"`

		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test > tmp.log 2>&1 <<EOF
set enable_bitmapscan = on;
set enable_indexscan = off;
set enable_seqscan = off;
explain select * from btree_test where a >= $v order by a limit $n;
select * from btree_test where a >= $v order by a limit $n;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		q=`grep row tmp.log | tail -n 1 | awk '{print $1}' | sed 's/(//'`
		cat tmp.log >> $LOGFILE

		echo "btree-sort" $t $r $n $q bitmapscan uncached $e $v >> $RESULTS 2>&1


		t=`date +%s`

		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test >> $LOGFILE 2>&1 <<EOF
set enable_bitmapscan = on;
set enable_indexscan = off;
set enable_seqscan = off;
explain select * from btree_test where a >= $v order by a limit $n;
select * from btree_test where a >= $v order by a limit $n;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		echo "btree-sort" $t $r $n $q bitmapscan cached $e $v >> $RESULTS 2>&1

	done


	for r in `seq 1 2`; do

		t=`date +%s`

		echo "======================== seqscan $t ========================" >> $LOGFILE 2>&1

		PATH=$HOME/pg-master/bin:$PATH_OLD

		pg_ctl -D $DATADIR -l pg.log -w stop >> $LOGFILE 2>&1
		pg_ctl -D $DATADIR -l pg.log -w start >> $LOGFILE 2>&1

		sudo ./drop-caches.sh >> $LOGFILE 2>&1

		v=`psql test -t -A -c "select (random() * $d)::int"`

		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test > tmp.log 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = off;
set enable_seqscan = on;
explain select * from btree_test where a >= $v order by a limit $n;
select * from btree_test where a >= $v order by a limit $n;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		q=`grep row tmp.log | tail -n 1 | awk '{print $1}' | sed 's/(//'`
		cat tmp.log >> $LOGFILE

		echo "btree-sort" $t $r $n $q seqscan uncached $e $v >> $RESULTS 2>&1


		t=`date +%s`

		s=`psql test -t -A -c 'select extract(epoch from now())'`

		psql test >> $LOGFILE 2>&1 <<EOF
set enable_bitmapscan = off;
set enable_indexscan = off;
set enable_seqscan = on;
explain select * from btree_test where a >= $v order by a limit $n;
select * from btree_test where a >= $v order by a limit $n;
EOF

		e=`psql test -t -A -c "select (extract(epoch from now()) - $s) * 1000"`

		echo "btree-sort" $t $r $n $q seqscan cached $e $v >> $RESULTS 2>&1

	done

done

psql test -c "drop table if exists btree_test" >> $LOGFILE 2>&1
