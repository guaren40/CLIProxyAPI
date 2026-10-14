#!/bin/sh
set -eu

# A Zeabur template mounts /data as a persistent volume. Plain Git deployment
# also starts without setup, but its local data is lost when Zeabur redeploys it.
umask 077
data_dir="${CLI_PROXY_DATA_DIR:-/data}"
config_file="$data_dir/config.yaml"
credentials_file="$data_dir/initial-credentials.txt"

# Keep existing Docker Compose installations using their mounted config file.
if [ -f /CLIProxyAPI/config.yaml ]; then
    exec "$@" -config /CLIProxyAPI/config.yaml
fi

mkdir -p "$data_dir/auths"

if [ ! -e "$config_file" ]; then
    port="${PORT:-8317}"
    case "$port" in
        ''|*[!0-9]*) echo 'PORT must be a number from 1 to 65535' >&2; exit 1 ;;
    esac
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo 'PORT must be a number from 1 to 65535' >&2
        exit 1
    fi

    api_key="${CLI_PROXY_API_KEY:-$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')}"
    management_key="${CLI_PROXY_MANAGEMENT_KEY:-$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')}"
    case "$api_key$management_key" in
        *[!a-zA-Z0-9_-]*) echo 'Keys may contain only letters, digits, _ and -' >&2; exit 1 ;;
    esac

    temp_config="$(mktemp "$data_dir/.config.XXXXXX")"
    temp_credentials="$(mktemp "$data_dir/.credentials.XXXXXX")"
    trap 'rm -f "$temp_config" "$temp_credentials"' EXIT HUP INT TERM
    cat > "$temp_config" <<EOF
config-version: 8
server:
  host: ""
  port: $port
management:
  allow-remote: true
  secret-key: "$management_key"
access:
  api-keys:
    - "$api_key"
oauth:
  auth-dir: "$data_dir/auths"
EOF
    cat > "$temp_credentials" <<EOF
API Key: $api_key
Management key: $management_key
EOF
    mv "$temp_credentials" "$credentials_file"
    mv "$temp_config" "$config_file"
    trap - EXIT HUP INT TERM

    if [ -z "${CLI_PROXY_API_KEY:-}" ] || [ -z "${CLI_PROXY_MANAGEMENT_KEY:-}" ]; then
        printf 'First-run credentials (also saved in %s):\n' "$credentials_file"
        printf 'API Key: %s\nManagement key: %s\n' "$api_key" "$management_key"
    else
        printf 'First-run credentials saved in %s\n' "$credentials_file"
    fi
elif [ ! -s "$config_file" ]; then
    echo "Configuration file is empty: $config_file" >&2
    exit 1
fi

exec "$@" -config "$config_file"
