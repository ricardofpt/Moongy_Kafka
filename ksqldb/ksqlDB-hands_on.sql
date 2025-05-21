-------------------
---- FILTERING ----
-------------------

-- Create a Stream and Insert Data
-- 1. Begin by creating a stream for orders in the editor (make sure to set auto.offset.reset = earliest):
CREATE stream orders (id INTEGER KEY, item VARCHAR, address STRUCT <  
city  VARCHAR, state VARCHAR >)
WITH (KAFKA_TOPIC='orders', VALUE_FORMAT='json', partitions=1);

-- 2. Next, insert orders into the new orders stream:
INSERT INTO orders(id, item, address)
VALUES(140, 'Yellow Item', STRUCT(city:='Areeiro', state:='LX'));
INSERT INTO orders(id, item, address)
VALUES(141, 'Teal Item', STRUCT(city:='Aliados', state:='PO'));
INSERT INTO orders(id, item, address)
VALUES(142, 'Violet Item', STRUCT(city:='Oeiras', state:='CA'));
INSERT INTO orders(id, item, address)
VALUES(143, 'Purple Item', STRUCT(city:='Alvalade', state:='LX'));
INSERT INTO orders(id, item, address)
VALUES(144, 'Green Item', STRUCT(city:='Gaia', state:='PO'));

-- Create a Filtered Stream
-- 1. Set the auto.offset.reset property to earliest so that the new filtered stream we are about to create 
-- will include the data we inserted in the previous step.
-- 2. Next, create a stream for only LX orders:
CREATE STREAM lx_orders AS SELECT * FROM ORDERS WHERE
 ADDRESS->STATE='LX' EMIT CHANGES;
 
-- Query the Filtered Stream
-- 1. To validate the filtered stream, run a query against your lx_orders topic:
SELECT * FROM lx_orders EMIT CHANGES;


---------------------------
---- LOOKUPS AND JOINS ----
---------------------------

-- Create a Table and Insert Data
-- 1. Begin by creating a table items:
CREATE TABLE items (id VARCHAR PRIMARY KEY, make VARCHAR, model VARCHAR, unit_price DOUBLE)
WITH (KAFKA_TOPIC='items', VALUE_FORMAT='avro', PARTITIONS=1);

-- 2. Insert data into the table:
INSERT INTO items VALUES('item_3', 'Skateboard', 'Element', 19.99);
INSERT INTO items VALUES('item_4', 'Surfboard', 'Semente', 29.99);
INSERT INTO items VALUES('item_7', 'Bicycle', 'Scott', 49.99);

-- Create Streams and Insert Data
-- 1. We’re going to create a different stream called orders, but first we need to remove the existing one with the following commands:
DROP STREAM lx_orders;
DROP STREAM orders;

-- 2. Create the new orders stream:
CREATE STREAM orders (ordertime BIGINT, orderid INTEGER, itemid VARCHAR, orderunits INTEGER)
WITH (KAFKA_TOPIC='item_orders', VALUE_FORMAT='avro', PARTITIONS=1);

-- 3. Create a stream orders_enriched that joins your items table and orders stream:
CREATE STREAM orders_enriched AS
SELECT o.*, i.*, 
	o.orderunits * i.unit_price AS total_order_value
FROM orders o LEFT OUTER JOIN items i
on o.itemid = i.id;

-- 4. Insert some data into the orders stream:
INSERT INTO orders VALUES (1620501334477, 65, 'item_7', 5);
INSERT INTO orders VALUES (1620502553626, 67, 'item_3', 2);
INSERT INTO orders VALUES (1620503110659, 68, 'item_7', 7);
INSERT INTO orders VALUES (1620504934723, 70, 'item_4', 1);
INSERT INTO orders VALUES (1620505321941, 74, 'item_7', 3);
INSERT INTO orders VALUES (1620506437125, 72, 'item_7', 9);
INSERT INTO orders VALUES (1620508354284, 73, 'item_3', 4);

-- Query Your Enriched Stream
-- 1. Next, enter a push query on orders_enriched:
SELECT * FROM orders_enriched EMIT CHANGES;


-------------------------
---- TRANSFORMATIONS ----
-------------------------

-- Query an Existing Stream and Inspect the Data
-- 1. Begin by selecting everything from the orders stream:
SELECT * FROM orders EMIT CHANGES;

-- 2. Scroll down to see the returned records. View the structure of one of the records by clicking on the caret in its upper left-hand corner.

-- 3. Now Stop your orders query.

-- Create a Persistent Transformation
-- 1. Create a persistent transformation with no address data:
CREATE STREAM orders_no_address_data AS
SELECT TIMESTAMPTOSTRING(ordertime, 'yyyy-MM-dd HH:mm:ss') AS order_timestamp, orderid, itemid, orderunits
FROM orders EMIT CHANGES;

-- Inspect the Transformed Stream
-- 1. Now select from the transformed stream:
SELECT * FROM orders_no_address_data EMIT CHANGES;


--------------------------------
---- FLATTEN NESTED RECORDS ----
--------------------------------

-- Create a Nested Stream
-- 1. Begin by creating a nested stream. If you’ve been working through earlier lessons, you may have to remove a previous orders stream, like so:
DROP STREAM orders_enriched DELETE TOPIC;
DROP STREAM orders_no_address_data DELETE TOPIC;
DROP STREAM orders DELETE TOPIC;

-- 2. Now create the new orders stream:
CREATE STREAM orders (ordertime BIGINT, orderid INTEGER, itemid VARCHAR, 
orderunits INTEGER,  address STRUCT< street  VARCHAR, city VARCHAR, state VARCHAR>)
WITH (KAFKA_TOPIC='orders', VALUE_FORMAT='json', PARTITIONS=1);

-- Insert and Inspect Data
-- 1. Insert some data into your orders stream:

INSERT INTO orders VALUES (1620504934723, 70, 'item_4', 1,
	STRUCT(street:='Av. Brasil', city:='Lisboa', state:='LX'));
INSERT INTO orders VALUES (16205059321941, 72, 'item_7', 9,
	STRUCT(street:='Av. Almeida Garrett', city:='Amadora', state:='LX'));
INSERT INTO orders VALUES (16205069437125, 73, 'item_3', 4,
	STRUCT(street:='Rua do Pinhal', city:='Cascais', state:='LX'));
INSERT INTO orders VALUES (1620508354284, 74, 'item_7', 3,
	STRUCT(street:='Travessa do Caldas', city:='Almada', state:='LX'));
	
-- 2. Change auto.offset.reset to earliest so that when you query the stream, you get the earliest message. Use a SELECT statement to validate that the data has been entered correctly:
SELECT * FROM orders EMIT CHANGES;

-- 3. Scroll down and view the current structure of a record by clicking the caret in its upper left-hand corner. You see the nesting.

-- Flatten the Records
-- 1. Now create a new query to flatten the records:
SELECT ordertime, orderid, itemid, orderunits, address->street AS street, address->city AS city, address->state AS state
FROM orders EMIT CHANGES;

-- 2. Expand another record, and you will see that your data structure has been flattened.

-- Make Your Query Persistent and Inspect the Data
-- 1. Make your query persistent by appending a CREATE STREAM AS statement to your code from Step 5:
CREATE STREAM orders_flat WITH (KAFKA_TOPIC='orders_flat') AS
SELECT ordertime, orderid, itemid, orderunits, address->street AS street, address->city AS city, address->state AS state
FROM orders EMIT CHANGES; 

-- 2. Next, write a SELECT statement against the new orders_flat stream:
SELECT * FROM orders_flat EMIT CHANGES;

-- 3. Expand the structures of the records in the new stream to see that they are flattened.


---------------------------------
---- CONVERTING DATA FORMATS ----
---------------------------------

-- Inspect Your Existing Data
-- 1. Begin by printing your orders_flat stream to show the existing JSON data:
PRINT orders_flat FROM BEGINNING;

-- 2. Stop the query. Then expand a record to see the JSON structure.

-- Change Your Data's Format and Inspect It Again
-- 1. Enter a CREATE STREAM AS statement, with VALUE_FORMAT set to delimited:
CREATE STREAM orders_csv
WITH(VALUE_FORMAT='delimited', KAFKA_TOPIC='orders_csv') AS
SELECT * FROM orders_flat EMIT CHANGES;

-- This will help to clean up the JSON you saw in Step 2.

-- 2. Run a PRINT statement to see your newly delimited data:
PRINT orders_csv FROM BEGINNING;

-- Scroll down and expand a record to see the comma-delimited fields.


-----------------------------
---- MERGING TWO STREAMS ----
-----------------------------

-- Create and Populate Streams
-- 1. First, create your orders_uk stream:
CREATE STREAM orders_uk (ordertime BIGINT, orderid INTEGER, itemid VARCHAR, orderunits INTEGER,
    address STRUCT< street VARCHAR, city VARCHAR, state VARCHAR>)
WITH (KAFKA_TOPIC='orders_uk', VALUE_FORMAT='json', PARTITIONS=1);

-- 2. Insert data into your orders_uk stream:
INSERT INTO orders_uk VALUES (1620501334477, 65, 'item_7', 5,
  STRUCT(street:='234 Thorpe Street', city:='York', state:='England'));
INSERT INTO orders_uk VALUES (1620502553626, 67, 'item_3', 2,
  STRUCT(street:='2923 Alexandra Road', city:='Birmingham', state:='England'));
INSERT INTO orders_uk VALUES (1620503110659, 68, 'item_7', 7,
  STRUCT(street:='536 Chancery Lane', city:='London', state:='England'));

-- 3. Next, create your orders_us stream:
CREATE STREAM orders_us (ordertime BIGINT, orderid INTEGER, itemid VARCHAR, orderunits INTEGER,
    address STRUCT< street VARCHAR, city VARCHAR, state VARCHAR>)
WITH (KAFKA_TOPIC='orders_us', VALUE_FORMAT='json', PARTITIONS=1);

-- 4. Insert data into your orders_us stream:
INSERT INTO orders_us VALUES (1620501334477, 65, 'item_7', 5,
  STRUCT(street:='6743 Lake Street', city:='Los Angeles', state:='California'));
INSERT INTO orders_us VALUES (1620502553626, 67, 'item_3', 2,
  STRUCT(street:='2923 Maple Ave', city:='Mountain View', state:='California'));
INSERT INTO orders_us VALUES (1620503110659, 68, 'item_7', 7,
  STRUCT(street:='1492 Wandering Way', city:='Berkley', state:='California'));

-- Query and Inspect Your Existing Data
-- 1. First, run a query on your orders_uk stream:
SELECT * FROM orders_uk EMIT CHANGES;

-- 2. Scroll down and expand a record. Notice that it's from the UK.

-- 3. Change your query to use the orders_us stream:
SELECT * FROM orders_us EMIT CHANGES;

-- 4. Scroll down to expand another record. Notice that it's from the US.

-- Create a Merged Stream
-- 1. Merge the orders_us and orders_uk streams into a new stream, orders_combined, using the following two queries:
CREATE STREAM orders_combined AS
SELECT 'US' AS source, ordertime, orderid, itemid, orderunits, address
FROM orders_us;

-- 2
INSERT INTO orders_combined
SELECT 'UK' AS source, ordertime, orderid, itemid, orderunits, address
FROM orders_uk;

-- Inspect Your Data Using the Flow Tab
-- 1. Now move to the Flow tab. See how orders_uk and orders_us flow in to create the orders_combined stream.
-- 2. Click on the orders_combined stream. On the right-hand side, look at the list of records. Notice that the stream contains records from the UK and from the US.


-------------------------------
---- SPLITTING TWO STREAMS ----
-------------------------------

-- Inspect Your Existing Data
-- 1. Begin by looking at the orders_combined stream from the previous exercise, which has orders from both the US and the UK:
SELECT * FROM orders_combined EMIT CHANGES;

-- Create New Split Streams
-- 1. Create a new stream to contain only orders from the US:
CREATE STREAM us_orders AS
SELECT * FROM orders_combined
WHERE source = 'US';

-- 2. Create another new stream to contain only orders from the UK:
CREATE STREAM uk_orders AS
SELECT * FROM orders_combined
WHERE source = 'UK';

-- Inspect Your Data Using the Flow Tab
-- 1. Move to the Flow tab. Click on the US_ORDERS stream. On the right-hand side, you see that the stream contains only orders from the US. Click on the UK_ORDERS stream and you see that it likewise contains only orders from the UK.


----------- END OF OPERATIONS HANDS-ON -----------


----------------------------
---- MATERIALIZED VIEWS ----
----------------------------

-- Create a New Stream and Insert Data
-- 1. Create a stream MOVEMENTS:
-- If you have a stream named MOVEMENTS from a previous lesson you can drop it with:
DROP TABLE PERSON_STATS DELETE TOPIC;
DROP STREAM MOVEMENTS DELETE TOPIC;

-- 2. Now create the new stream:
CREATE STREAM MOVEMENTS(PERSON VARCHAR KEY, LOCATION VARCHAR)
	WITH (VALUE_FORMAT='JSON', PARTITIONS=1, KAFKA_TOPIC='movements');

-- 3. Insert data into MOVEMENTS:
INSERT INTO MOVEMENTS VALUES ('Robin', 'York');
INSERT INTO MOVEMENTS VALUES ('Robin', 'Leeds');
INSERT INTO MOVEMENTS VALUES ('Allison', 'Denver');
INSERT INTO MOVEMENTS VALUES ('Robin', 'Ilkley');
INSERT INTO MOVEMENTS VALUES ('Allison', 'Boulder');

-- Run Queries with Aggregated Calculations
-- 1. To see the number of movements per person in the stream, enter the following query:
SELECT PERSON, COUNT (*)
FROM MOVEMENTS GROUP BY PERSON EMIT CHANGES;

-- 2. Edit the query to count the unique locations that each person has visited:
SELECT PERSON, COUNT_DISTINCT(LOCATION)
FROM MOVEMENTS GROUP BY PERSON EMIT CHANGES;

-- Create a Materialized View Table with Your Aggregated Calculations
-- 1. Now create a table that shows both aggregated calculations, combining PERSON, COUNT(*) and COUNT_DISTINCT(LOCATION):
CREATE TABLE PERSON_STATS AS
SELECT PERSON,
		LATEST_BY_OFFSET(LOCATION) AS LATEST_LOCATION,
		COUNT(*) AS LOCATION_CHANGES,
		COUNT_DISTINCT(LOCATION) AS UNIQUE_LOCATIONS
	FROM MOVEMENTS
GROUP BY PERSON
EMIT CHANGES;

-- Insert Additional Data and Query Your Table
-- 1. Insert more data into your MOVEMENTS stream to make the calculation more interesting:

INSERT INTO MOVEMENTS VALUES('Robin', 'Manchester');
INSERT INTO MOVEMENTS VALUES('Allison', 'Loveland');
INSERT INTO MOVEMENTS VALUES('Robin', 'London');
INSERT INTO MOVEMENTS VALUES('Allison', 'Aspen');
INSERT INTO MOVEMENTS VALUES('Robin', 'Ilkley');
INSERT INTO MOVEMENTS VALUES('Allison', 'Vail');
INSERT INTO MOVEMENTS VALUES('Robin', 'York');

-- 2. SELECT a person’s name to see how many times they have changed locations and how many unique locations they have visited:
SELECT * FROM PERSON_STATS WHERE PERSON = 'Allison';


---------------------------
---- PULL/PUSH QUERIES ----
---------------------------

-- 1. Issue a pull query on the PERSON_STATS table:
SELECT LATEST_LOCATION, LOCATION_CHANGES, UNIQUE_LOCATIONS
FROM PERSON_STATS WHERE PERSON = 'Allison';

-- 2. Now issue a push query on the PERSON_STATS table:
SELECT LATEST_LOCATION, LOCATION_CHANGES, UNIQUE_LOCATIONS
FROM PERSON_STATS WHERE PERSON = 'Allison' EMIT CHANGES;

-- 3. Next, in another window, or perhaps in the CLI, insert some more data into the MOVEMENTS stream on which the PERSON_STATS table is based:
INSERT INTO MOVEMENTS VALUES ('Robin', 'York');
INSERT INTO MOVEMENTS VALUES ('Robin', 'Leeds');
INSERT INTO MOVEMENTS VALUES ('Allison', 'Denver');
INSERT INTO MOVEMENTS VALUES ('Robin', 'Ilkley');
INSERT INTO MOVEMENTS VALUES ('Allison', 'Boulder');

-- 4. You should see new entries, reflecting this new data, appearing in the results of the push query from step 2.

-- 5. Kill the query with Stop. Push queries will run until they're manually killed.


--------------------------
---- LAMBDA FUNCTIONS ----
--------------------------

-- Transform Function
-- 1. Create a Stream with a MAP
-- Create a stream1 with exam scores as a MAP field:
CREATE STREAM stream1 (
    id INT, name VARCHAR,
    exam_scores MAP<STRING, DOUBLE>
) WITH (
    kafka_topic = 'topic1', partitions = 1,
    value_format = 'json'
); 

-- 2. Create a Stream Using Transform
-- Create a stream transformed using the TRANSFORM function:
CREATE STREAM transformed 
    AS SELECT id, name,
    TRANSFORM(exam_scores,(k, v) => UCASE(k), (k, v) => (ROUND(v))) AS rounded_scores
FROM stream1 EMIT CHANGES;

-- 3. Insert Data and Query
-- Insert some data into stream1:
INSERT into stream1 values(1, 'Lisa', MAP('Nov':=93.53, 'Feb':=94.13, 'May':=96.83));
INSERT into stream1 values(1, 'Larry', MAP('Nov':=83.53, 'Feb':=84.82, 'May':=85.27));
INSERT into stream1 values(1, 'Melissa', MAP('Nov':=97.20, 'Feb':=96.47, 'May':=98.62));
INSERT into stream1 values(1, 'Chris', MAP('Nov':=92.78, 'Feb':=91.15, 'May':=93.91));

-- 4. Run a query on the transformed stream:
SELECT * FROM transformed EMIT CHANGES;


-- Reduce Function
-- 1. Create a Stream with an ARRAY
-- Create stream2 with a points ARRAY field:
CREATE STREAM stream2 (
    name VARCHAR,
    points ARRAY<INTEGER>
) WITH (
    kafka_topic = 'topic2', partitions = 1,
    value_format = 'json'
);

-- 2. Create a Stream Using Reduce
-- Create a reduced stream using the REDUCE function.
CREATE STREAM reduced 
    AS SELECT name,
    REDUCE(points,0,(s,x)=> (s+x)) AS total
FROM stream2 EMIT CHANGES;

-- 3. Insert Data and Query
-- Insert some data into stream2:
INSERT INTO stream2 VALUES('Misty', Array[7, 5, 8, 8, 6]);
INSERT INTO stream2 VALUES('Marty', Array[3, 5, 4, 6, 4]);
INSERT INTO stream2 VALUES('Mary', Array[9, 7, 8, 7, 8]);
INSERT INTO stream2 VALUES('Mickey', Array[8, 6, 8, 7, 5]);

-- 4. Run a query on the reduced stream:
SELECT * FROM reduced EMIT CHANGES;


-- Filter Function
-- 1. Create a Stream with an ARRAY
-- Create a stream3 with a numbers ARRAY field:
CREATE STREAM stream3 (
    id VARCHAR,
    numbers ARRAY<INTEGER>
) WITH (
    kafka_topic = 'topic3', partitions = 1,
    value_format = 'json'
);

-- 2.Create a Stream with Filter
-- Create a filtered stream using the FILTER function:
CREATE STREAM filtered 
    AS SELECT id,
    FILTER(numbers,x => (x%2 = 0)) AS even_numbers
FROM stream3 EMIT CHANGES;

-- 3.Insert Data and Query
-- Insert some data into stream3:
INSERT INTO stream3 VALUES('Group1', ARRAY[1, 2, 3,4,5,6,7,8,9,10,11,12,13,14,15]);

-- 4. Create a push query to run on the filtered stream:
SELECT * FROM filtered EMIT CHANGES;
