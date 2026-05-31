# Build stage
FROM golang:1.24 AS build

WORKDIR /src

COPY app/main.go .

# Build a statically linked binary so it runs on a minimal base image
RUN CGO_ENABLED=0 GOOS=linux go build -o /app main.go

# Run stage
FROM gcr.io/distroless/static-debian12

COPY --from=build /app /app

EXPOSE 4444

ENTRYPOINT ["/app"]
