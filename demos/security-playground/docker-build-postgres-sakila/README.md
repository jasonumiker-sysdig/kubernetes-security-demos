## PostgreSQL Docker image for Sakila sample database

* Image is based on [postgres:15.2-bullseye](https://hub.docker.com/_/postgres/)
* Initialized with [Sakila port for PostgreSQL](https://github.com/jOOQ/jOOQ/tree/master/jOOQ-examples/Sakila/postgres-sakila-db) 

Sample usage:
```
docker run -e POSTGRES_PASSWORD=sakila -p 5432:5432 -d frantiseks/postgres-sakila
```
