\timing on

COPY part FROM '/mnt/raid/tpch/part.csv' WITH CSV DELIMITER '|';
COPY region FROM '/mnt/raid/tpch/region.csv' WITH CSV DELIMITER '|';
COPY nation FROM '/mnt/raid/tpch/nation.csv' WITH CSV DELIMITER '|';
COPY supplier FROM '/mnt/raid/tpch/supplier.csv' WITH CSV DELIMITER '|';
COPY customer FROM '/mnt/raid/tpch/customer.csv' WITH CSV DELIMITER '|';
COPY partsupp FROM '/mnt/raid/tpch/partsupp.csv' WITH CSV DELIMITER '|';
COPY orders FROM '/mnt/raid/tpch/orders.csv' WITH CSV DELIMITER '|';
COPY lineitem FROM '/mnt/raid/tpch/lineitem.csv' WITH CSV DELIMITER '|';

\d+
