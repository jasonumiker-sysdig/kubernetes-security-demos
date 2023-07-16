#!/bin/bash
docker buildx create --name mybuilder --bootstrap --use --file ./Dockerfile-unprivileged
docker buildx build --push \
  --platform linux/arm64,linux/amd64 \
  --tag public.ecr.aws/m9h2b5e7/security-playground-unprivileged:110623 \
  .
docker buildx build --push \
  --platform linux/arm64,linux/amd64 \
  --tag public.ecr.aws/m9h2b5e7/security-playground-unprivileged:latest \
  .
docker buildx rm mybuilder