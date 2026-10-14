# The builder and runtime stages use ARM64 images; the result is ARM64 only.
FROM --platform=linux/arm64 golang:1.26-bookworm AS builder
WORKDIR /app

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends build-essential binutils ca-certificates tzdata git; \
    rm -rf /var/lib/apt/lists/*

COPY go.mod go.sum ./

RUN go mod download

COPY . .

ARG VERSION=dev
ARG COMMIT=none
ARG BUILD_DATE=unknown

RUN set -eux; \
    CGO_ENABLED=1 GOOS=linux GOARCH=arm64 CC=gcc go build -buildvcs=false \
      -ldflags="-s -w -X 'main.Version=${VERSION}' -X 'main.Commit=${COMMIT}' -X 'main.BuildDate=${BUILD_DATE}'" \
      -o /app/CLIProxyAPI ./cmd/server/; \
    readelf -h /app/CLIProxyAPI | grep -Eq 'Machine:[[:space:]]*AArch64'; \
    chmod 0755 /app/deploy/zeabur-entrypoint.sh

# The runtime image is ARM64 only.
FROM --platform=linux/arm64 debian:bookworm-slim

WORKDIR /CLIProxyAPI
COPY --from=builder /app/CLIProxyAPI ./CLIProxyAPI
COPY --from=builder /app/deploy/zeabur-entrypoint.sh ./entrypoint.sh
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
COPY config.example.yaml ./config.example.yaml

ENV TZ=Asia/Shanghai PORT=8317 SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
EXPOSE 8317

ENTRYPOINT ["/CLIProxyAPI/entrypoint.sh"]
CMD ["/CLIProxyAPI/CLIProxyAPI"]
