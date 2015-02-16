#!/bin/bash
set -e

if [ "$1" = 'postgres' ]; then
	if [ -z "$(ls -A "$PGDATA")" ]; then
		echo 'Empty data directory. Attach correct volume or initialize using initdb.'
		exit 1
	fi

	chown -R postgres "$PGDATA"

	exec gosu postgres "$@"
fi

if [ "$1" = 'pg_basebackup' ]; then
	chown -R postgres "$PGDATA"

	exec gosu postgres "$@"
fi

if [ "$1" = 'initdb' ]; then
	if [ ! -z "$(ls -A "$PGDATA")" ]; then
		echo 'Data directory already exists'
		exit 1
	fi

	chown -R postgres "$PGDATA"

	gosu postgres initdb

	sed -ri "s/^#(listen_addresses\s*=\s*)\S+/\1'*'/" "$PGDATA"/postgresql.conf

	# check password first so we can ouptut the warning before postgres
	# messes it up
	if [ "$POSTGRES_PASSWORD" ]; then
		pass="PASSWORD '$POSTGRES_PASSWORD'"
		authMethod=md5
	else
		# The - option suppresses leading tabs but *not* spaces. :)
		cat >&2 <<-'EOWARN'
		****************************************************
		WARNING: No password has been set for the database.
		Use "-e POSTGRES_PASSWORD=password" to set
		it in "docker run".
		****************************************************
		EOWARN

		pass=
		authMethod=trust
	fi

	: ${POSTGRES_USER:=postgres}
	if [ "$POSTGRES_USER" = 'postgres' ]; then
		op='ALTER'
	else
		op='CREATE'
		gosu postgres postgres --single -jE <<-EOSQL
		CREATE DATABASE "$POSTGRES_USER" ;
		EOSQL
		echo
	fi

	gosu postgres postgres --single -jE <<-EOSQL
	$op USER "$POSTGRES_USER" WITH SUPERUSER $pass ;
	EOSQL
	echo

	{ echo; echo "host all \"$POSTGRES_USER\" 0.0.0.0/0 $authMethod"; } >> "$PGDATA"/pg_hba.conf

	if [ -d /docker-entrypoint-initdb.d ]; then
		for f in /docker-entrypoint-initdb.d/*.sh; do
			[ -f "$f" ] && . "$f"
		done
	fi

	exit 0
fi

if [ "$1" = 'psql' ]; then
	exec gosu postgres "$@"
fi

exec "$@"
