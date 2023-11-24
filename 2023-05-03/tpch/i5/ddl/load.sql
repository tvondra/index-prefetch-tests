\timing on

COPY part FROM '/var/lib/postgresql/tpch-filters/data/part.csv' WITH CSV DELIMITER '|';
COPY region FROM '/var/lib/postgresql/tpch-filters/data/region.csv' WITH CSV DELIMITER '|';
COPY nation FROM '/var/lib/postgresql/tpch-filters/data/nation.csv' WITH CSV DELIMITER '|';
COPY supplier FROM '/var/lib/postgresql/tpch-filters/data/supplier.csv' WITH CSV DELIMITER '|';
COPY customer FROM '/var/lib/postgresql/tpch-filters/data/customer.csv' WITH CSV DELIMITER '|';
COPY partsupp FROM '/var/lib/postgresql/tpch-filters/data/partsupp.csv' WITH CSV DELIMITER '|';
COPY orders FROM '/var/lib/postgresql/tpch-filters/data/orders.csv' WITH CSV DELIMITER '|';
COPY lineitem FROM '/var/lib/postgresql/tpch-filters/data/lineitem.csv' WITH CSV DELIMITER '|';

\d+
