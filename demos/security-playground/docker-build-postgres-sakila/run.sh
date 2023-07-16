#!/bin/bash
docker run -e POSTGRES_PASSWORD=sakila -p 5432:5432 -d --name postgres jasonumiker/postgres-sakila:latest
