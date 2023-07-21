\set ECHO none
\out /dev/null

BEGIN ISOLATION LEVEL SERIALIZABLE;

-- Add the real uuid_generate_v7 function to allow it to be tested
\i uuid_generate_v7.sql

-- Temporary clock_timestamp() function for tests
CREATE FUNCTION
  pg_temp.clock_timestamp()
RETURNS
  timestamptz
LANGUAGE
  sql
AS $$
  SELECT
    clock_timestamp()
$$
;

-- Temporarily move built-in functions out of public schema
ALTER FUNCTION
  gen_random_bytes(count integer)
SET SCHEMA
  test
;

ALTER FUNCTION
  clock_timestamp
SET SCHEMA
  test
;

-- Create stub built-in functions
CREATE FUNCTION
  gen_random_bytes(count integer)
RETURNS
  bytea
LANGUAGE
  sql
AS $$
  SELECT
    '\x0fffffffffffffffffff'::bytea
$$
;

CREATE FUNCTION
  extract_timestamp_uuidv7(uuid uuid)
RETURNS
  timestamptz
LANGUAGE
  sql
IMMUTABLE
PARALLEL SAFE
STRICT
LEAKPROOF
AS $$
  SELECT
    to_timestamp
      ( ('x0000' || left(replace(uuid::text, '-', ''), 12))::bit(64)::bigint / 1000::numeric
      )
$$
;

/*

Big endian byte order for v7 uuid

+-------+-----------+------------+
|  byte | bit range | label      |
+-------+-----------+------------+
|     0 |   0 |   7 | unix_ts_ms |
|     1 |   8 |  15 |            |
|     2 |  16 |  23 |            |
|     3 |  24 |  31 |            |
|     4 |  32 |  39 |            |
|     5 |  40 |  47 |            |
|     6 |  48 |  51 | ver        |
|     6 |  52 |  55 | rand_a     |
|     7 |  56 |  63 |            |
|     8 |  64 |  65 | var        |
|     8 |  66 |  71 | rand_b     |
|     9 |  72 |  79 |            |
|    10 |  80 |  87 |            |
|    11 |  88 |  97 |            |
|    12 |  96 | 103 |            |
|    13 | 104 | 111 |            |
|    14 | 112 | 119 |            |
|    15 | 120 | 127 |            |
+-------+-----+-----+------------+
*/

CREATE TEMPORARY VIEW
  test
AS
  /*
    get_bit uses little-endian order, while a uuid is in big-endian. The
    position argument 0 is the right-most bit within each byte, but the
    specification assumes version and variant start at the left-most bit.

    In order to display the correct version and variant we need to access each
    bit in reverse order, from right to left within each byte.
  */
  SELECT
    uuid_generate_v7
  , pg_typeof(uuid_generate_v7)                expected_type
  , substr(uuid_generate_v7::text, 15, 1)      expected_version
  , get_bit(bytes, 55)::bit(1) ||
    get_bit(bytes, 54)::bit(1) ||
    get_bit(bytes, 53)::bit(1) ||
    get_bit(bytes, 52)::bit(1)                 expected_version_binary
  , get_bit(bytes, 71)::bit(1) ||
    get_bit(bytes, 70)::bit(1)                 expected_variant_binary
  , pg_temp.clock_timestamp()                  input_timestamp
  , extract_timestamp_uuidv7(uuid_generate_v7) serialized_timestamp
  FROM
    uuid_generate_v7()
  CROSS JOIN
    uuid_send(uuid_generate_v7) _ (bytes)
;

SAVEPOINT test_setup;

\out
\df uuid_generate_v7
\out /dev/null

\echo -- With a clock_timestamp having the smallest serializable timestamp
\echo -- (1 row)
\echo

CREATE FUNCTION
  clock_timestamp()
RETURNS
  timestamptz
LANGUAGE
  sql
AS $$
  SELECT
    '1970-01-01 00:00:00'::timestamptz
$$
;

-- The serialized timestamp is unchanged
SELECT
  *
FROM
  test
\gx /dev/stdout

ROLLBACK TO test_setup;

\echo
\echo -- With a clock_timestamp having the largest serializable timestamp
\echo -- (1 row)
\echo

CREATE FUNCTION
  clock_timestamp()
RETURNS
  timestamptz
LANGUAGE
  sql
AS $$
  SELECT
    '10889-08-02 05:31:50.65504'::timestamptz
$$
;

-- The serialized timestamp is unchanged
SELECT
  *
FROM
  test
\gx /dev/stdout

ROLLBACK TO test_setup;

\echo
\echo -- With a clock_timestamp with 999 milliseconds
\echo -- (1 row)
\echo

CREATE FUNCTION
  clock_timestamp()
RETURNS
  timestamptz
LANGUAGE
  sql
AS $$
  SELECT
    '1970-01-01 00:00:00.999'::timestamptz
$$
;

-- The serialized timestamp is unchanged
SELECT
  *
FROM
  test
\gx /dev/stdout

ROLLBACK TO test_setup;

\echo
\echo -- With a clock_timestamp with 9994 milliseconds
\echo -- (1 row)
\echo

CREATE FUNCTION
  clock_timestamp()
RETURNS
  timestamptz
LANGUAGE
  sql
AS $$
  SELECT
    '1970-01-01 00:00:00.9994'::timestamptz
$$
;

-- The serialized timestamp is rounded down to 999 milliseconds
SELECT
  *
FROM
  test
\gx /dev/stdout

ROLLBACK TO test_setup;

\echo
\echo -- With a clock_timestamp with 9995 milliseconds
\echo -- (1 row)
\echo

CREATE FUNCTION
  clock_timestamp()
RETURNS
  timestamptz
LANGUAGE
  sql
AS $$
  SELECT
    '1970-01-01 00:00:00.9995'::timestamptz
$$
;

-- The serialized timestamp is rounded up to next second
SELECT
  *
FROM
  test
\gx /dev/stdout

\echo
\echo -- With a clock_timestamp for 2022-02-22T14:22:22.00-05:00
\echo -- with rand_a of 0xcc3
\echo -- with rand_b of 0x18c4dc0c0c07398f
\echo -- (1 row)
\echo

CREATE OR REPLACE FUNCTION
  clock_timestamp()
RETURNS
  timestamptz
LANGUAGE
  sql
AS $$
  SELECT
    '2022-02-22T14:22:22.00-05:00'::timestamptz
$$
;

-- Set random bytes equivalent to UUIDv7 example:
-- https://uuid6.github.io/uuid6-ietf-draft/#name-example-of-a-uuidv7-value
CREATE OR REPLACE FUNCTION
  gen_random_bytes(count integer)
RETURNS
  bytea
LANGUAGE
  sql
AS $$
  SELECT
    '\x0cc3'::bytea ||           -- rand_a
    '\x18c4dc0c0c07398f'::bytea  -- rand_b
$$
;

SELECT
  *
FROM
  test
\gx /dev/stdout

ROLLBACk;
