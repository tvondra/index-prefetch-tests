\timing on

COPY part FROM PROGRAM 'lz4 -d -c /mnt/data/tpch/100/part.csv.lz4' WITH CSV DELIMITER '|';
COPY region FROM PROGRAM 'lz4 -d -c /mnt/data/tpch/100/region.csv.lz4' WITH CSV DELIMITER '|';
COPY nation FROM PROGRAM 'lz4 -d -c /mnt/data/tpch/100/nation.csv.lz4' WITH CSV DELIMITER '|';
COPY supplier FROM PROGRAM 'lz4 -d -c /mnt/data/tpch/100/supplier.csv.lz4' WITH CSV DELIMITER '|';
COPY customer FROM PROGRAM 'lz4 -d -c /mnt/data/tpch/100/customer.csv.lz4' WITH CSV DELIMITER '|';
COPY partsupp FROM PROGRAM 'lz4 -d -c /mnt/data/tpch/100/partsupp.csv.lz4' WITH CSV DELIMITER '|';
COPY orders FROM PROGRAM 'lz4 -d -c /mnt/data/tpch/100/orders.csv.lz4' WITH CSV DELIMITER '|';
COPY lineitem FROM PROGRAM 'lz4 -d -c /mnt/data/tpch/100/lineitem.csv.lz4' WITH CSV DELIMITER '|';

\d+

