# Build stage
FROM golang:1.24 AS build

WORKDIR /src

COPY app/main.go .

# Build a statically linked binary so it runs on a minimal base image
RUN CGO_ENABLED=0 GOOS=linux go build -o /app main.go

# Run stage
FROM alpine:3.20

COPY --from=build /app /app

EXPOSE 4444

HEALTHCHECK --interval=10s --timeout=2s CMD wget -qO- http://localhost:4444/ || exit 1

ENTRYPOINT ["/app"]
