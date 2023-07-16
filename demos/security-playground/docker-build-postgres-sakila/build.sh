#!/bin/bash
docker buildx create --name mybuilder --bootstrap --use
docker buildx build --push \
  --platform linux/arm64,linux/amd64 \
  --tag public.ecr.aws/m9h2b5e7/postgres-sakila:110623 \
  .
docker buildx build --push \
  --platform linux/arm64,linux/amd64 \
  --tag public.ecr.aws/m9h2b5e7/postgres-sakila:latest \
  .
docker buildx rm mybuilder