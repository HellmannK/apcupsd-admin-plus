docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -f Podmanfile -t localhost/apcupsd-cgi . --push --no-cache