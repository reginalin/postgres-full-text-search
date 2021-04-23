# Postgres Full Text Search exploration

Let's learn about Postgres full text search! We will use some cool wine review data from this [Kaggle dataset](https://www.kaggle.com/zynicide/wine-reviews) because wine not?

## Setup

Run `make run` to start up the docker containers for the database and `pgadmin`.

Decompress `wine-data.zip` by running `make unzip`.

### Initialize database

Within `pgadmin` run

```sql
CREATE TABLE wine (
    id integer NOT NULL,
    country text,
    description text,
    designation text,
    points integer,
    price numeric,
    province text,
    region_1 text,
    region_2 text,
    variety text,
    winery text,
    CONSTRAINT wine_pkey PRIMARY KEY (id)
)
```

Decompress `wine-data.zip`. To import the data from the csv file, run

```sql
COPY wine
FROM '/var/lib/postgresql/data/winemag-data_first150k.csv'
DELIMITER ','
CSV HEADER;
```
