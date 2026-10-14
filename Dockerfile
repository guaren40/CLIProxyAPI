# The build runs on Zeabur's build host, while the resulting image is always ARM64.
FROM --platform=$BUILDPLATFORM golang:1.26-bookworm AS builder

WORKDIR /app

RUN set -eux; \
    apt-get update; \
    case "$(dpkg --print-architecture)" in \
      amd64) apt-get install -y --no-install-recommends build-essential binutils gcc-aarch64-linux-gnu ca-certificates tzdata git ;; \
      arm64) apt-get install -y --no-install-recommends build-essential binutils ca-certificates tzdata git ;; \
      *) echo 'Only amd64 and arm64 build hosts are supported' >&2; exit 1 ;; \
    esac; \
    rm -rf /var/lib/apt/lists/*

COPY go.mod go.sum ./

RUN go mod download

COPY . .

ARG VERSION=dev
ARG COMMIT=none
ARG BUILD_DATE=unknown

RUN set -eux; \
    if [ "$(dpkg --print-architecture)" = arm64 ]; then export CC=gcc; else export CC=aarch64-linux-gnu-gcc; fi; \
    CGO_ENABLED=1 GOOS=linux GOARCH=arm64 go build -buildvcs=false \
      -ldflags="-s -w -X 'main.Version=${VERSION}' -X 'main.Commit=${COMMIT}' -X 'main.BuildDate=${BUILD_DATE}'" \
      -o /app/CLIProxyAPI ./cmd/server/; \
    readelf -h /app/CLIProxyAPI | grep -Eq 'Machine:[[:space:]]*AArch64'; \
    chmod 0755 /app/deploy/zeabur-entrypoint.sh

# Do not add RUN instructions below: an amd64 build host must not execute ARM64 binaries.
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
