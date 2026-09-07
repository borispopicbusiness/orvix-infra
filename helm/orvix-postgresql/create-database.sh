#!/bin/sh

psql "$1" -v ON_ERROR_STOP=1 \
  -v db_name="orvix-${POD_NAMESPACE}" <<'SQL'
CREATE DATABASE :"db_name";
SQL