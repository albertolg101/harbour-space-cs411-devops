# Debug Task

## Hypotheses

1. **The whole image is arm64.** A plain `docker build` on Mac stamps the
   image config with `architecture: arm64` and ships an arm64 binary, so the
   amd64 VM pulls a single-arch arm64 image it physically can't run.

2. **The manifest says amd64 but the binary inside is still arm64.** If the
   runtime stage was forced to amd64 but the `go build` wasn't (no `GOARCH`), the
   metadata looks correct while the ELF in `/app/main` is the wrong arch — the two
   layers disagree.

## One check per guess

For guess 1, ask the registry what architecture the image claims:

```sh
docker manifest inspect ttl.sh/albertolg101:2h | grep architecture
```

If it only lists `"architecture": "arm64"`, it's guess 1.

For guess 2, look past the metadata at the binary itself on the VM:

```sh
docker run --rm --entrypoint="" ttl.sh/albertolg101:2h file /app/main
```

If the manifest said amd64 but `file` reports `ELF ... ARM aarch64`, it's guess 2.

## Fix

Stay minimal — no framework changes, just build for the VM's arch with buildx and
push in one go:

```sh
docker buildx build --platform linux/amd64 -t ttl.sh/albertolg101:2h --push .
```

Because the build stage now runs as amd64, the `CGO_ENABLED=0 GOOS=linux go build`
already in the Dockerfile produces an amd64 binary, so the metadata and the ELF
both end up amd64. (If I want it to keep running on my Mac too, I'd use
`--platform linux/amd64,linux/arm64` instead.)

## Underlying lesson

"The image is built" only promises the layers assembled on my build host's
architecture — it says nothing about whether the binary inside can actually
execute on the x86_64 runtime host.
