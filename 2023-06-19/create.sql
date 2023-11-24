-- table to load data into

-- equality tests
create table point_tests (
    test text,
    machine text,
    time bigint,
    rows bigint,
    dataset text,
    matches bigint,
    ndistinct bigint,
    build text,
    prefetch bigint,
    table_size bigint,
    index_size bigint,
    scan_type text,
    caching text,
    run int,
    value int,
    nfound bigint,
    cost double precision,
    duration double precision);

-- scalar array operator tests
create table saop_tests (
    test text,
    machine text,
    time bigint,
    rows bigint,
    dataset text,
    matches bigint,
    ndistinct bigint,
    build text,
    nvalues bigint,
    distance bigint,
    prefetch bigint,
    table_size bigint,
    index_size bigint,
    scan_type text,
    caching text,
    run int,
    value int,
    nfound bigint,
    cost double precision,
    duration double precision);

-- views aggregating runs for the same combination of parameters
create view point_tests_agg as
select
  test, machine, rows, dataset, matches, ndistinct, build, prefetch, table_size, index_size, scan_type, caching,
  avg(nfound)::bigint as nfound,
  count(*) AS count,
  percentile_disc(0.5) within group (order by cost) AS cost,
  percentile_disc(0.5) within group (order by duration) AS duration
from point_tests
group by test, machine, rows, dataset, matches, ndistinct, build, prefetch, table_size, index_size, scan_type, caching
order by test, machine, rows, dataset, matches, ndistinct, build, prefetch, table_size, index_size, scan_type, caching;

create view saop_tests_agg as
select
  test, machine, rows, dataset, matches, ndistinct, build, nvalues, distance, prefetch, table_size, index_size, scan_type, caching,
  avg(nfound)::bigint as nfound,
  count(*) AS count,
  percentile_disc(0.5) within group (order by cost) AS cost,
  percentile_disc(0.5) within group (order by duration) AS duration
from saop_tests
group by test, machine, rows, dataset, matches, ndistinct, build, nvalues, distance, prefetch, table_size, index_size, scan_type, caching
order by test, machine, rows, dataset, matches, ndistinct, build, nvalues, distance, prefetch, table_size, index_size, scan_type, caching;

-- comparison of the same combination without/with the patch
create view point_master_vs_patched as
with
  master as (select * from point_tests_agg where build = 'master'),
  patched as (select * from point_tests_agg where build = 'patched')
select
  master.*,
  patched.cost as patched_cost,
  patched.duration as patched_duration,
  (100.0 * patched.duration / master.duration) as speedup
from master join patched using (test, machine, rows, dataset, matches, ndistinct, prefetch, scan_type, caching)
order by master.rows, master.test, master.caching, master.scan_type, master.dataset, master.machine, master.prefetch, master.matches, master.ndistinct;

create view saop_master_vs_patched as
with
  master as (select * from saop_tests_agg where build = 'master'),
  patched as (select * from saop_tests_agg where build = 'patched')
select
  master.*,
  patched.cost as patched_cost,
  patched.duration as patched_duration,
  (100.0 * patched.duration / master.duration) as speedup
from master join patched using (test, machine, rows, dataset, matches, ndistinct, prefetch, scan_type, caching, nvalues, distance)
order by master.rows, master.test, master.caching, master.scan_type, master.dataset, master.machine, master.prefetch, master.matches, master.ndistinct, master.nvalues, master.distance;

-- comparison of the same combination for bitmapscan and indexscan
create view point_bitmapscan_vs_indexscan as
with
  bitmapscan as (select * from point_tests_agg where scan_type = 'bitmapscan'),
  indexscan as (select * from point_tests_agg where scan_type = 'indexscan')
select
  bitmapscan.*,
  indexscan.cost as indexscan_cost,
  indexscan.duration as indexscan_duration,
  (100.0 * indexscan.duration / bitmapscan.duration) as speedup
from bitmapscan join indexscan using (test, machine, rows, dataset, matches, ndistinct, prefetch, build, caching)
order by bitmapscan.rows, bitmapscan.test, bitmapscan.caching, bitmapscan.build, bitmapscan.dataset, bitmapscan.machine, bitmapscan.prefetch, bitmapscan.matches, bitmapscan.ndistinct;

create view saop_bitmapscan_vs_indexscan as
with
  bitmapscan as (select * from saop_tests_agg where scan_type = 'bitmapscan'),
  indexscan as (select * from saop_tests_agg where scan_type = 'indexscan')
select
  bitmapscan.*,
  indexscan.cost as indexscan_cost,
  indexscan.duration as indexscan_duration,
  (100.0 * indexscan.duration / bitmapscan.duration) as speedup
from bitmapscan join indexscan using (test, machine, rows, dataset, matches, ndistinct, prefetch, build, caching, nvalues, distance)
order by bitmapscan.rows, bitmapscan.test, bitmapscan.caching, bitmapscan.build, bitmapscan.dataset, bitmapscan.machine, bitmapscan.prefetch, bitmapscan.matches, bitmapscan.ndistinct, bitmapscan.nvalues, bitmapscan.distance;


select test, rows, dataset, matches, ndistinct, machine, prefetch, caching, count,
  avg(table_size)::bigint AS table_size, avg(index_size)::bigint AS index_size, avg(nfound)::bigint AS nfound,
  min(duration) filter (where build = 'master') as bitmap_master,
  min(indexscan_duration) filter (where build = 'master') as index_master,
  min(duration) filter (where build = 'patched') as bitmap_patched,
  min(indexscan_duration) filter (where build = 'patched') as index_patched,
  min(cost) filter (where build = 'master') as bitmap_cost_master,
  min(indexscan_cost) filter (where build = 'master') as index_cost_master,
  min(cost) filter (where build = 'patched') as bitmap_cost_patched,
  min(indexscan_cost) filter (where build = 'patched') as index_cost_patched,
  (min(speedup) filter (where build = 'master'))::int  as master,
  (min(speedup) filter (where build = 'patched'))::int  as patched,
  (100.0 * min(speedup) filter (where build = 'patched') / min(speedup) filter (where build = 'master'))::int as diff
from point_bitmapscan_vs_indexscan group by 1, 2, 3, 4, 5, 6, 7, 8, 9
order by rows, machine, test, caching, dataset, prefetch, matches, ndistinct;

select test, rows, dataset, matches, ndistinct, machine, prefetch, caching, count, nvalues, distance,
  avg(table_size)::bigint AS table_size, avg(index_size)::bigint AS index_size, avg(nfound)::bigint AS nfound,
  min(duration) filter (where build = 'master') as bitmap_master,
  min(indexscan_duration) filter (where build = 'master') as index_master,
  min(duration) filter (where build = 'patched') as bitmap_patched,
  min(indexscan_duration) filter (where build = 'patched') as index_patched,
  min(cost) filter (where build = 'master') as bitmap_cost_master,
  min(indexscan_cost) filter (where build = 'master') as index_cost_master,
  min(cost) filter (where build = 'patched') as bitmap_cost_patched,
  min(indexscan_cost) filter (where build = 'patched') as index_cost_patched,
  (min(speedup) filter (where build = 'master'))::int  as master,
  (min(speedup) filter (where build = 'patched'))::int  as patched,
  (100.0 * min(speedup) filter (where build = 'patched') / min(speedup) filter (where build = 'master'))::int as diff
from saop_bitmapscan_vs_indexscan group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
order by rows, machine, test, caching, dataset, prefetch, matches, ndistinct, nvalues, distance;



select * from (
  select test, rows, dataset, matches, ndistinct, machine, prefetch, caching, count,
    avg(table_size)::bigint AS table_size, avg(index_size)::bigint AS index_size, avg(nfound)::bigint AS nfound,
    min(duration) filter (where build = 'master') as bitmap_master,
    min(indexscan_duration) filter (where build = 'master') as index_master,
    min(duration) filter (where build = 'patched') as bitmap_patched,
    min(indexscan_duration) filter (where build = 'patched') as index_patched,
    min(cost) filter (where build = 'master') as bitmap_cost_master,
    min(indexscan_cost) filter (where build = 'master') as index_cost_master,
    min(cost) filter (where build = 'patched') as bitmap_cost_patched,
    min(indexscan_cost) filter (where build = 'patched') as index_cost_patched,
    (min(speedup) filter (where build = 'master'))::int  as master,
    (min(speedup) filter (where build = 'patched'))::int  as patched,
    (100.0 * min(speedup) filter (where build = 'patched') / min(speedup) filter (where build = 'master'))::int as diff
  from point_bitmapscan_vs_indexscan group by 1, 2, 3, 4, 5, 6, 7, 8, 9
  order by rows, machine, test, caching, dataset, prefetch, matches, ndistinct
) foo
where (index_cost_master < bitmap_cost_master)  -- index scan would be selected (and not bitmap scan)
  and (index_patched > greatest(index_master * 1.05, index_master + 5.0)) -- slowed down by at least 5% or 5ms
order by index_patched / index_master desc;


select * from (
  select test, rows, dataset, matches, ndistinct, machine, prefetch, caching, count, nvalues, distance,
    avg(table_size)::bigint AS table_size, avg(index_size)::bigint AS index_size, avg(nfound)::bigint AS nfound,
    min(duration) filter (where build = 'master') as bitmap_master,
    min(indexscan_duration) filter (where build = 'master') as index_master,
    min(duration) filter (where build = 'patched') as bitmap_patched,
    min(indexscan_duration) filter (where build = 'patched') as index_patched,
    min(cost) filter (where build = 'master') as bitmap_cost_master,
    min(indexscan_cost) filter (where build = 'master') as index_cost_master,
    min(cost) filter (where build = 'patched') as bitmap_cost_patched,
    min(indexscan_cost) filter (where build = 'patched') as index_cost_patched,
    (min(speedup) filter (where build = 'master'))::int  as master,
    (min(speedup) filter (where build = 'patched'))::int  as patched,
    (100.0 * min(speedup) filter (where build = 'patched') / min(speedup) filter (where build = 'master'))::int as diff
  from saop_bitmapscan_vs_indexscan group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
  order by rows, machine, test, caching, dataset, prefetch, matches, ndistinct, nvalues, distance
) foo
where (index_cost_master < bitmap_cost_master)  -- index scan would be selected (and not bitmap scan)
  and (index_patched > greatest(index_master * 1.05, index_master + 5.0)) -- slowed down by at least 5% or 5ms
order by index_patched / index_master desc;

-- average cost per combination of parameters, for the given scan type
create or replace function point_cost(r point_tests, p_scan_type text) returns double precision as $$
  select percentile_cont(0.5) within group (order by cost) from point_tests where (test, machine, rows, dataset, matches, build, prefetch, caching, scan_type) = (r.test, r.machine, r.rows, r.dataset, r.matches, r.build, r.prefetch, r.caching, p_scan_type);
$$ language sql;

create or replace function saop_cost(r saop_tests, p_scan_type text) returns double precision as $$
  select percentile_cont(0.5) within group (order by cost) from saop_tests where (test, machine, rows, dataset, matches, nvalues, distance, build, prefetch, caching, scan_type) = (r.test, r.machine, r.rows, r.dataset, r.matches, r.nvalues, r.distance, r.build, r.prefetch, r.caching, p_scan_type);
$$ language sql;

create or replace function point_cheapest(r point_tests) returns bool as $$
  select point_cost(r, r.scan_type) = least(point_cost(r, 'indexscan'), point_cost(r, 'bitmapscan'), point_cost(r, 'seqscan'));
$$ language sql;

create or replace function saop_cheapest(r saop_tests) returns bool as $$
  select saop_cost(r, r.scan_type) = least(saop_cost(r, 'indexscan'), saop_cost(r, 'bitmapscan'), saop_cost(r, 'seqscan'));
$$ language sql;

create index on point_tests (test, machine, rows, dataset, matches, build, prefetch, caching, scan_type);

create index on saop_tests (test, machine, rows, dataset, matches, nvalues, distance, build, prefetch, caching, scan_type);
