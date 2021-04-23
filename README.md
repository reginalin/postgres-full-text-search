# Dive into Postgres Full Text Search

Let's learn about Postgres full text search! In this tutorial we will use some built-in Postgres features to analyze some cool wine review data from this [Kaggle dataset](https://www.kaggle.com/zynicide/wine-reviews) because wine not?

By the end you:

- should be able to identify whether Postgres full text search (FTS) is suitable for your needs
- will be familiar with the key concepts behind FTS
- have experience working with FTS directly in a Postgres database

## Search Overview

If you have been tasked with adding search functionality to a web application, Postgres FTS is often a good starting point if:

- Postgres is already part of your stack
- search is not be _the_ key element of your website
- your database is fairly small (likely does not have millions of rows of data yet)
- you want something quick to set up

At this stage, Postgres will likely be good enough for your needs (check out this popular article [Postres full-text search is Good Enough!](http://rachbelaid.com/postgres-full-text-search-is-good-enough/), which has trended multiple times in the past on Hacker News -- the discussion there is interesting to read through as well). If you later find that you need additional functionality or search that scales better, you might then seek out technologies based off [Apache Lucene](https://lucene.apache.org/), which powers popular platforms like [ElasticSearch](https://www.elastic.co/elasticsearch/) and [Apache Solr](https://solr.apache.org/).

### What exactly is "full text search"?

If you have worked with queries in the past, you will likely be familiar with something like **substring search**, which returns an exact match to something like a regular expression. Typically, this makes use of operators such as `like` and `ilike` and will handle matching prefixes and substrings.

>  Given the text `Can you deliver the pizza?`, searching `deliv`, `delive`, and `deliver` will match.
However, `delivering`, `delivery`, and `delivers` will not, even though the words share the same semantic root.

**Full text search** does allow us to leverage word meanings when searching. In the above example, `delivering`, `delivery`, and `delivers` would match.

This richer search functionality is provided through preprocessing efforts. Given a _document_ of text, full-text search involves the following preprocessing steps:

- parsing of documents --> tokens
  - requires a **parser**
  - this involves things like splitting up text by whitespace into words
- normalizing of tokens --> lexemes, aka semantic word roots
  - requires **dictionaries** and **template** functions that make use of them
  - this involves standardizing word casing, removing suffixes, and removing _stop words_ like "in", "the", "and", etc.

When configuring your Postgres database, you have the option to set up specific dictionaries, templates, and parsers, if you want something other than the default.

## Trying it out

Now, let's dive in and experiment with Postgres FTS.

In this repo we have a `docker-compose.yml` file that will run a Postgres database and a database GUI tool called `pgadmin`. Run `make run` to build and start up the two docker containers.

Now, if you navigate to `http://localhost:5050`, you should see the `pgadmin` web interface. Connect to "Server Group 1" by entering our super secure password `password` (the configuration for this can be found in `pgadmin/servers.json`).

Great! Now we are connected to the server that holds our database, `db`.

### Transferring CSV data into our Postgres database

Next, we want to set up our wine data and import it into the database. If you navigate to the 'pgdata/' directory, you will notice a `wine-data.zip` file inside. This contains a csv file of ~150,000 wine reviews from the Kaggle dataset.

#### Decompress data

In a separate terminal (since we want to make sure that our docker containers are still running) run `make unzip` to decompress `wine-data.zip`. If the command fails for you, first run `sudo apt install unzip`.

Now, within `pgdata/` you should see a decompressed csv file containing our data. Let's set up a table to store it in.

#### Set up database table

If you look at the `winemag-data_first150k.csv` file, you'll see rows of comma-separated data in csv format. Run `head -10 winemag-data_first150k.csv` to inspect the first 10 lines.

We can see that the first row contains the names of the columns:
> id,country,description,designation,points,price,province,region_1,region_2,variety,winery

We want to create a database table that contains these specific columns. Launch the query tool within `pgadmin` and run:

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

Now we have a table named `wine` with the specified columns. We have set a primary key on the `id` column, which means that we will rely on `id` to distinguish between rows. Usually, we would want to use the Postgres `uuid` type for this column, but the `id` fields provided by the Kaggle dataset are integers.

#### Import csv data

Next, we want to copy the csv data into our database.

```sql
COPY wine
FROM '/var/lib/postgresql/data/winemag-data_first150k.csv'
DELIMITER ','
CSV HEADER
```
If you take a look at our docker-compose file, you will notice that we have mounted the `pgdata` file containing our csv file into the `/var/lib/postgresql/data/` directory. This lets our database container access our local csv file.

We specify the comma delimiter and the csv filetype, and add `HEADER` so that the database knows to ignore our first row.

#### Querying the table

To check that we have imported our data properly, run

```
SELECT * from wine
```

And voila! We should be able to see our wine reviews.

### Experiment with Data

#### tsvector and tsquery

Before we start querying our data, we need to be familiar with two Postgres data types: `tsvector` and `tsquery`.

- `tsvector` is the vectorized form of our docuemnt
- `tsquery` is a query of search terms

To see what this looks like, run

```sql
SELECT * from to_tsvector('testing out to see how this works')
```

The functions `to_tsvector` and `to_tsquery` allow us to convert text into the appropriate data types.

#### Match operator

We can use the **match operator** `@@`, which returns true if a `tsvector` document matches a `tsquery` query.

```sql
# tsquery type allows for different operators

# 'and' operator
SELECT to_tsvector('hello world') @@ to_tsquery('hello & world');

# 'or' operator
SELECT to_tsvector('hello world') @@ to_tsquery('hello | worlds');

# followed by operator
SELECT to_tsvector('world hello') @@ to_tsquery('hello <-> world')
```

#### Search the wine table

Now we are ready to search through our data!

Let's search for the term 'wine' within the `description` column of our `wine` table.

```sql
# Here we specify that we want the 'english' dictionary configuration
select *
from wine
where to_tsvector('english', description) @@ to_tsquery('english', 'wine');
```

We can also create a tsvector out of multiple columns. Use the concatenation operator `||`. Below, we add include a space in between the concatenation of our two columns to ensure that the words are tokenized properly.

```sql
# search through a description + country vector
select *
from wine
where to_tsvector(description || ' ' || country) @@ to_tsquery('US');
```

### Gin index
Now, you may be noticing that your queries may not exactly be blazing fast. The query above took 3 secs 807 ms for me -- not too bad, but we can definitely improve on this time. Looking at our queries above, you will notice that we are repeatedly converting the columns to tsvectors with each query, which is not exactly efficient. To speed this up, we want to store this computed tsvector and create an index.

> Index refresher:
> - indexes make lookups faster
> - imagine searching through a book for a particular topic. Rather than skimming the whole book, you can look at the index for the page numbers corresponding to the topic.
> - you may be familiar with b-tree indices, which are often used for sorting

We want to use a `GIN` index (generalized inverted index), which is recommended by Postgres for full text search. GIN indexes map each lexeme to a compressed list of locations.

You may also use a GiST index as an alternative -- this index takes up less space but generally leads to longer searches. Depending on your needs, you may select either index.

But here we will use a GIN index. First, we will create a column named `search_vector` to store our tsvector document. We will use the Postgres **stored generated** column, which ensures that our `search_vector` column wil be automatically updated if the `description` or `country` columns are changed.

```sql
# coalesce lets us set up a default value in case of null terms
ALTER TABLE wine
ADD COLUMN search_vector tsvector
GENERATED ALWAYS AS (to_tsvector('english', description || ' ' || coalesce(country, '')))
STORED
```

Now we can create the index:

```sql
CREATE INDEX search_idx
on wine using gin(search_vector)
```

Let's re-run our query against our new column:

```sql
SELECT *
from wine
where search_vector @@ to_tsquery('US');
```
It should be faster than before! For me, it took just 604 ms.

### Other features 

Postgres FTS supports ranking results and giving more weight to certain results than others. The queries that we have tried so far have simply checked that a match exists, but what if we want to do something like return results with more matches first?

We can use `ts_rank`, which ranks based on the frequency of matching lexemes:

```sql
SELECT *, ts_rank_cd(search_vector, query) AS rank
from wine, plainto_tsquery('aromas note') query
WHERE search_vector @@ query
ORDER BY rank DESC;
```

Apart from the Postgres built-in ranking functions, you can also implement your own. Keep in mind, though that ranking requires some additional overhead.

## Summary

Congrats! By now, you should have an idea of the main concepts behind Postgres full text search, and how to import datasets to play around with. If this article interested you, stick around for a walk-through of Postgres FTS implemented using sqlalchemy.

## Additional Resources

- Youtube video: [The State of Full Text Search in PostgresQL 12](https://www.youtube.com/watch?v=c8IrUHV70KQ&t=1999s)
- the Postgres [docs](https://www.postgresql.org/docs/current/textsearch.html)
- Alternative: [trigram search](https://www.postgresql.org/docs/13/pgtrgm.html)

____

Author: Regina Lin (reginalin714@gmail.com)

