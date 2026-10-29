# Build stage
FROM golang:1.25-alpine AS build

RUN apk add --no-cache git

WORKDIR /src

COPY go.work go.work.sum* ./
COPY libs/ libs/
COPY gen/ gen/
COPY services/auth/ services/auth/

WORKDIR /src/services/auth

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/auth-server ./cmd/server

# Runtime stage
FROM alpine:3.20

RUN addgroup -S app && adduser -S app -G app
USER app

COPY --from=build /out/auth-server /usr/local/bin/auth-server

EXPOSE 50051

ENTRYPOINT ["/usr/local/bin/auth-server"]