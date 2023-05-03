\timing on

COPY part FROM PROGRAM 'lz4 -c -d /mnt/data/tpch/50/part.csv.lz4' WITH CSV DELIMITER '|';
COPY region FROM PROGRAM 'lz4 -c -d /mnt/data/tpch/50/region.csv.lz4' WITH CSV DELIMITER '|';
COPY nation FROM PROGRAM 'lz4 -c -d /mnt/data/tpch/50/nation.csv.lz4' WITH CSV DELIMITER '|';
COPY supplier FROM PROGRAM 'lz4 -c -d /mnt/data/tpch/50/supplier.csv.lz4' WITH CSV DELIMITER '|';
COPY customer FROM PROGRAM 'lz4 -c -d /mnt/data/tpch/50/customer.csv.lz4' WITH CSV DELIMITER '|';
COPY partsupp FROM PROGRAM 'lz4 -c -d /mnt/data/tpch/50/partsupp.csv.lz4' WITH CSV DELIMITER '|';
COPY orders FROM PROGRAM 'lz4 -c -d /mnt/data/tpch/50/orders.csv.lz4' WITH CSV DELIMITER '|';
COPY lineitem FROM PROGRAM 'lz4 -c -d /mnt/data/tpch/50/lineitem.csv.lz4' WITH CSV DELIMITER '|';

\d+
