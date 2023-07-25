CREATE OR REPLACE FUNCTION
  uuid_generate_v7()
RETURNS
  uuid
LANGUAGE
  plpgsql
PARALLEL SAFE
AS $$
  DECLARE
    -- The current UNIX timestamp in milliseconds
    unix_time_ms CONSTANT bytea NOT NULL DEFAULT substring(int8send((extract(epoch FROM clock_timestamp()) * 1000)::bigint) from 3);

    -- The buffer used to create the UUID, starting with the UNIX timestamp and followed by random bytes
    buffer                bytea NOT NULL DEFAULT unix_time_ms || gen_random_bytes(10);
  BEGIN
    -- Set most significant 4 bits of 7th byte to 7 (for UUID v7), keeping the last 4 bits unchanged
    buffer = set_byte(buffer, 6, (b'0111' || get_byte(buffer, 6)::bit(4))::bit(8)::int);

    -- Set most significant 2 bits of 9th byte to 2 (the UUID variant specified in RFC 4122), keeping the last 6 bits unchanged
    buffer = set_byte(buffer, 8, (b'10'   || get_byte(buffer, 8)::bit(6))::bit(8)::int);

    RETURN encode(buffer, 'hex');
  END
$$
;
