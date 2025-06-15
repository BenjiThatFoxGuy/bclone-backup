# Using the PostgreSQL backend

## Environment Variables

#### PG_CONNECTION_STRING

PostgreSQL connection URL in DSN format, **required**.
Format: `postgresql://username:password@host:port/database`

Example:
```
PG_CONNECTION_STRING="postgresql://user:pass@localhost:5432/mydb"
```

#### Connecting to Multiple Databases

Use numbered variables (PG_CONNECTION_STRING_1, PG_CONNECTION_STRING_2, etc):

```
PG_CONNECTION_STRING_1="postgresql://user1:pass1@host1:5432/db1"
PG_CONNECTION_STRING_2="postgresql://user2:pass2@host2:5432/db2"
```

<br>



## Backup

Specify the above environment variables to switch to the PostgreSQL database.

<br>



## Restore

When restoring, also specify the PostgreSQL connection string(s) to switch to the PostgreSQL database.

1. Ensure that the database is accessible.

Perhaps you will use the `docker-compose up -d [services name]` command to start the database separately.

2. Verify that the connection string host is accessible.

If your database is running in docker-compose, you need to find the corresponding network name via `docker network ls` and add `--network=[name]` to the restore command to specify the network name.

3. Restore and restart the container.
