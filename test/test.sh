#!/usr/bin/env bash

# Reference:
# http://www.davidpashley.com/articles/writing-robust-shell-scripts/
# http://kvz.io/blog/2013/11/21/bash-best-practices/
# http://redsymbol.net/articles/unofficial-bash-strict-mode/

set -o errexit    # Exit when an expression fails
set -o noclobber  # Disable automatic file overwriting
set -o noglob     # Disable shell globbing
set -o nounset    # Exit when an undefined variable is used
set -o pipefail   # Exit when a command in a pipeline fails
set -o posix      # Ensure posix semantics

IFS=$'\n\t'  # Set default field separator to not split on spaces

umask 0077

export PGDATABASE=${PGDATABASE:-test}

readonly TEST_FILE=test/uuid_generate_v7.test.sql
readonly GOLDEN_TEST_FILE=$TEST_FILE.expected

create_db_if_not_exists() {
  psql --field-separator $'\t' --list --no-align --no-psqlrc --tuples-only \
    | cut -f 1                                                             \
    | grep --line-regexp --quiet "$PGDATABASE"                             \
  || createdb --encoding UTF8
}

setup_db() {
  psql --no-psqlrc --quiet --set ON_ERROR_STOP=1 <<SQL
  SET client_min_messages TO warning;
  ALTER DATABASE $PGDATABASE SET TIMEZONE TO 'UTC';
  CREATE EXTENSION IF NOT EXISTS pgcrypto;
  CREATE SCHEMA IF NOT EXISTS test;
SQL
}

regenerate_golden_test() {
  psql --file "$TEST_FILE" --no-psqlrc --set ON_ERROR_STOP=1 \
    | sed 's/[ \t]*$//'                                      \
    | sed '$d'                                               \
    >| "$GOLDEN_TEST_FILE"
}

reset_golden_test() {
  git checkout --quiet -- "$GOLDEN_TEST_FILE" 2> /dev/null
}

create_db_if_not_exists
setup_db

echo '1..1' # We are going to run 1 test

regenerate_golden_test

# Successful if test passes
if git diff --exit-code --quiet -- "$GOLDEN_TEST_FILE"
then
  echo 'ok 1 - uuid_generate_v7 test'
  reset_golden_test
else
  echo 'not ok 1 - uuid_generate_v7 test'
  exit 1
fi
