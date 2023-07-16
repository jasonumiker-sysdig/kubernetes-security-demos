#!/bin/bash
docker buildx create --name mybuilder --bootstrap --use
docker buildx build --push \
  --platform linux/arm64,linux/amd64 \
  --tag public.ecr.aws/m9h2b5e7/security-playground:110623 \
  .
#docker buildx build --push \
#  --platform linux/arm64,linux/amd64 \
#  --tag public.ecr.aws/m9h2b5e7/security-playground:latest \
#  .
docker buildx rm mybuilder