echo "truncate point_tests;"
echo "truncate saop_tests;"

for f in i5/*.csv xeon/*.csv; do

	x=`realpath $f`

    if [[ "$f" =~ "saop" ]]; then
		echo "copy saop_tests from '$x' with (format csv, delimiter ' ', header true);"
	else
		echo "copy point_tests from '$x' with (format csv, delimiter ' ', header true);"
    fi

done

echo 'analyze;'

echo "copy (select *, point_cheapest(p.*), point_cost(p.*, 'indexscan') as indexscan, point_cost(p.*, 'bitmapscan') as bitmapscan, point_cost(p.*, 'seqscan') as seqscan from point_tests p order by rows, machine, test, caching, dataset, prefetch, matches, ndistinct, build, scan_type, run) to '/home/user/point-raw.csv' with (format csv, delimiter E'\t', header true);"

echo "copy (select *, saop_cheapest(s.*), saop_cost(s.*, 'indexscan') as indexscan, saop_cost(s.*, 'bitmapscan') as bitmapscan, saop_cost(s.*, 'seqscan') as seqscan from saop_tests s order by rows, machine, test, caching, dataset, prefetch, matches, ndistinct, nvalues, distance, run) to '/home/user/saop-raw.csv' with (format csv, delimiter E'\t', header true);"

echo "copy (select test, rows, dataset, matches, ndistinct, machine, prefetch, caching, count, nvalues, distance,
  avg(table_size)::bigint AS table_size, avg(index_size)::bigint AS index_size, avg(nfound)::bigint AS nfound,
  min(duration) filter (where build = 'master') as bitmap_master,
  min(indexscan_duration) filter (where build = 'master') as index_master,
  min(duration) filter (where build = 'patched') as bitmap_patched,
  min(indexscan_duration) filter (where build = 'patched') as index_patched,
  (min(speedup) filter (where build = 'master'))::int  as master,
  (min(speedup) filter (where build = 'patched'))::int  as patched,
  (100.0 * min(speedup) filter (where build = 'patched') / min(speedup) filter (where build = 'master'))::int as diff
from saop_bitmapscan_vs_indexscan group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
order by rows, machine, test, caching, dataset, prefetch, matches, ndistinct, nvalues, distance) to '/home/user/saop.csv' with (format csv, delimiter E'\t', header true);"

echo "copy (select test, rows, dataset, matches, ndistinct, machine, prefetch, caching, count,                   
  avg(table_size)::bigint AS table_size, avg(index_size)::bigint AS index_size, avg(nfound)::bigint AS nfound,
  min(duration) filter (where build = 'master') as bitmap_master,
  min(indexscan_duration) filter (where build = 'master') as index_master,
  min(duration) filter (where build = 'patched') as bitmap_patched,
  min(indexscan_duration) filter (where build = 'patched') as index_patched,
  (min(speedup) filter (where build = 'master'))::int  as master,
  (min(speedup) filter (where build = 'patched'))::int  as patched,
  (100.0 * min(speedup) filter (where build = 'patched') / min(speedup) filter (where build = 'master'))::int as diff
from point_bitmapscan_vs_indexscan group by 1, 2, 3, 4, 5, 6, 7, 8, 9
order by rows, machine, test, caching, dataset, prefetch, matches, ndistinct) to '/home/user/point.csv' with (format csv, delimiter E'\t', header true);"
