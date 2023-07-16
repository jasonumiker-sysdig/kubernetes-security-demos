docker buildx create --name mybuilder --bootstrap --use
docker buildx build --push \
  --platform linux/arm64,linux/amd64 \
  --tag jasonumiker/hello-app:180623 \
  .
docker buildx build --push \
  --platform linux/arm64,linux/amd64 \
  --tag hello-app:latest public.ecr.aws/m9h2b5e7/hello-app:latest \
  .
docker buildx rm mybuilder