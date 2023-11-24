select test, machine, rows, dataset, nmatches, ndistinct, build, prefetch, scan_type, caching, percentile_cont(0.5) within group (order by duration) as duration
  from point_results as duration
 group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
 order by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10;

select test, machine, rows, dataset, nmatches, ndistinct, build, prefetch, scan_type, caching, percentile_cont(0.5) within group (order by duration) as duration
  from point_results
 where best_plan=1
 group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
 order by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10;
