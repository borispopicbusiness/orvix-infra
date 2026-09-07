#!/bin/sh

psql "$1" -v ON_ERROR_STOP=1 <<'SQL'
CREATE DATABASE orvix;
SQL