drop table if exists lineitem_clustered;
drop table if exists orders_clustered;

create table lineitem_clustered (like lineitem);

with order_dates as (
    select
        o_orderkey,
        o_orderdate AS date_old,
        '1992-01-01'::date + (o_orderkey * 2405.0 / 600000000)::int AS date_new
    from orders
)
insert into lineitem_clustered select
  l_orderkey
, l_partkey
, l_suppkey
, l_linenumber
, l_quantity
, l_extendedprice
, l_discount
, l_tax
, l_returnflag
, l_linestatus
, l_shipdate + (order_dates.date_new - order_dates.date_old)
, l_commitdate + (order_dates.date_new - order_dates.date_old)
, l_commitdate + (order_dates.date_new - order_dates.date_old)
, l_shipinstruct
, l_shipmode
, l_comment
from lineitem join order_dates on (order_dates.o_orderkey = lineitem.l_orderkey) order by o_orderkey;



create table orders_clustered (like orders);

insert into orders_clustered select
  o_orderkey
, o_custkey
, o_orderstatus
, o_totalprice
, '1992-01-01'::date + (o_orderkey * 2405.0 / 600000000)::int
, o_orderpriority
, o_clerk
, o_shippriority
, o_comment
from orders order by o_orderkey;
