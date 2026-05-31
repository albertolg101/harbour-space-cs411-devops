# Build stage
FROM golang:1.24@sha256:d2d2bc1c84f7e60d7d2438a3836ae7d0c847f4888464e7ec9ba3a1339a1ee804 AS build

WORKDIR /src

COPY app/main.go .

# Build a statically linked binary so it runs on a minimal base image
RUN CGO_ENABLED=0 GOOS=linux go build -o /app main.go

# Run stage
FROM alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc

COPY --from=build /app /app

EXPOSE 4444

HEALTHCHECK --interval=10s --timeout=2s CMD wget -qO- http://localhost:4444/ || exit 1

ENTRYPOINT ["/app"]
