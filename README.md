# uuid_generate_v7

This is a PostgreSQL PL/pgSQL function for creating v7 UUIDs, designed in line with the latest [v7 UUID specification](https://www.ietf.org/archive/id/draft-peabody-dispatch-new-uuid-format-01.html#name-uuidv7-layout-and-bit-order).

## Overview

The `uuid_generate_v7` function is a tool for generating v7-like UUIDs in PostgreSQL. It merges the current UNIX timestamp in milliseconds with 10 random bytes to create unique identifiers, complying with the [UUID RFC 4122 specification](https://datatracker.ietf.org/doc/html/rfc4122#section-4).

## Benefits

A v7 UUID has a distinct advantage over v4 because the timestamp prefix allows them to be partially sequential. This allows better indexing performance in comparison to completely random UUIDs (v4). This is particularly beneficial for databases that frequently insert and search records.

## Collision Risk

The chance of collision is extremely low due to the large size and randomness of UUIDs. UUID uniqueness is derived from the combination of the current UNIX timestamp in milliseconds and 10 random bytes. The risk of collision further decreases with the use of a cryptographically secure random number generator, `gen_random_bytes`.

To give you a sense of the collision risk: assuming a perfect random number generator and generating 1 billion UUIDs every second, you'd need to keep generating for about 100 years to have a 1 in a billion chance of a single collision.

## Testing

You can run the tests using this command:†

```bash
test/test.sh

# Successful Output:
# 1..1
# ok 1 - uuid_generate_v7 test
```

The test environment and golden test files will be set up and validated. Differences between the test output and the golden file will cause the test to fail.

† Tests require PostgreSQL 12+.
