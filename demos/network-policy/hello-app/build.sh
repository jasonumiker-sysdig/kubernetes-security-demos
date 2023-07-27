docker buildx create --name mybuilder --bootstrap --use
docker buildx build --push \
  --platform linux/arm64,linux/amd64 \
  --tag public.ecr.aws/m9h2b5e7/hello-app:270723 \
  .
docker buildx build --push \
  --platform linux/arm64,linux/amd64 \
  --tag public.ecr.aws/m9h2b5e7/hello-app:latest \
  .
docker buildx rm mybuilder