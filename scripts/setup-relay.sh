#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
LanternDesk Linux relay setup (Debian / Ubuntu)

  sudo bash scripts/setup-relay.sh --host PUBLIC_IPV4_OR_DNS
  bash scripts/setup-relay.sh --host relay.example.com --render-only

Options:
  --host HOST     Public IPv4 address or DNS name, without scheme or port.
  --dir PATH      Installation directory (default: /opt/lanterndesk-relay).
  --render-only   Print Compose configuration; do not install or start anything.
  -h, --help      Show this help.

Installs Docker and Compose if missing, starts hbbs/hbbr, and prints the public
client configuration. Re-running preserves data and server keys. Open TCP
21115-21117 and UDP 21116 in the server firewall/cloud security group yourself.
EOF
}

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

relay_host=''
install_dir=/opt/lanterndesk-relay
render_only=false
while (($#)); do
    case "$1" in
        --host|--dir)
            (($# >= 2)) || fail "$1 requires a value"
            if [[ $1 == --host ]]; then relay_host=$2; else install_dir=$2; fi
            shift 2
            ;;
        --render-only) render_only=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Unknown option: $1 (see --help)" ;;
    esac
done

[[ ${#relay_host} -le 253 && $relay_host =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ && $relay_host != *..* ]] ||
    fail '--host must be an IPv4 address or DNS name without scheme, port or spaces'
[[ $install_dir == /* && $install_dir != / && $install_dir != *$'\n'* ]] ||
    fail '--dir must be an absolute directory path other than /'
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
template="$script_dir/../deploy/relay/compose.yaml"
[[ -f $template ]] || fail "Missing template: $template"

render_compose() {
    sed 's/${RELAY_HOST:?Set RELAY_HOST}/'"$relay_host"'/g' "$template"
}

if $render_only; then
    render_compose
    exit 0
fi

[[ $(uname -s) == Linux ]] || fail 'This installer requires Linux'
[[ $EUID -eq 0 ]] || fail 'Run this command with sudo (or use --render-only)'

compose=()
find_compose() {
    if docker compose version >/dev/null 2>&1; then
        compose=(docker compose)
    elif command -v docker-compose >/dev/null 2>&1; then
        compose=(docker-compose)
    else
        return 1
    fi
}

if ! command -v docker >/dev/null 2>&1 || ! find_compose; then
    [[ -r /etc/os-release ]] || fail 'Cannot identify Linux distribution'
    . /etc/os-release
    [[ ${ID:-} == debian || ${ID:-} == ubuntu || ${ID_LIKE:-} == *debian* || ${ID_LIKE:-} == *ubuntu* ]] ||
        fail 'Automatic Docker installation supports Debian/Ubuntu; install Docker and Compose first on other distributions'
    apt-get update
    if ! command -v docker >/dev/null 2>&1; then
        apt-get install -y docker.io
    fi
    if ! find_compose; then
        compose_package=docker-compose
        for package in docker-compose-v2 docker-compose-plugin; do
            if apt-cache show "$package" 2>/dev/null | grep '^Package:' >/dev/null; then
                compose_package=$package
                break
            fi
        done
        apt-get install -y "$compose_package"
    fi
fi
find_compose || fail 'Docker Compose is unavailable after installation'
systemctl enable --now docker
docker info >/dev/null

umask 077
mkdir -p -- "$install_dir/data"
chmod 700 -- "$install_dir/data"
if [[ -e $install_dir/data/id_ed25519 || -e $install_dir/data/id_ed25519.pub ]]; then
    [[ -s $install_dir/data/id_ed25519 && -s $install_dir/data/id_ed25519.pub ]] ||
        fail "Incomplete key pair in $install_dir/data; restore both files from backup before restarting"
fi
render_compose > "$install_dir/compose.yaml"
cd -- "$install_dir"
compose+=(--project-name lanterndesk-relay -f "$install_dir/compose.yaml")
"${compose[@]}" config --quiet
"${compose[@]}" pull

# Start one key writer first; both processes must load the same key pair.
"${compose[@]}" up -d hbbr
for ((attempt = 0; attempt < 30; attempt++)); do
    if [[ -s data/id_ed25519 && -s data/id_ed25519.pub ]]; then break; fi
    sleep 1
done
[[ -s data/id_ed25519 && -s data/id_ed25519.pub ]] || {
    "${compose[@]}" logs --tail=30 hbbr
    fail 'Relay did not generate its key pair within 30 seconds'
}
chmod 600 data/id_ed25519
"${compose[@]}" up -d
sleep 1
for service in hbbr hbbs; do
    container_id=$("${compose[@]}" ps -q "$service")
    if [[ -z $container_id || $(docker inspect --format '{{.State.Running}}' "$container_id") != true ]]; then
        "${compose[@]}" logs --tail=30 "$service"
        fail "$service is not running"
    fi
done

public_key=$(tr -d '\r\n' < data/id_ed25519.pub)
[[ $public_key =~ ^[A-Za-z0-9+/]{43}=$ ]] || fail 'Invalid server public key; inspect the server logs'
printf '{"host":"%s:21116","relay":"%s:21117","api":"","key":"%s"}\n' \
    "$relay_host" "$relay_host" "$public_key" > client-config.json
base64 -w0 client-config.json | tr '+/' '-_' | rev > client-config.txt
chmod 644 client-config.json client-config.txt

cat <<EOF

LanternDesk relay is running.
ID server:     $relay_host:21116
Relay server:  $relay_host:21117
API server:    (leave empty)
Key:           $public_key

Allow inbound TCP 21115-21117 and UDP 21116 in your server firewall and cloud
security group. This script does not change firewall rules. Web ports are not
published. Configure BOTH desktop clients under Settings > Network > ID/Relay
server, or copy client-config.txt and choose Import server config.

Public client files: $install_dir/client-config.{json,txt}
Private server data: $install_dir/data (back up this entire directory)

Management commands:
EOF
for operation in 'ps' 'logs --tail=100' 'restart' 'stop'; do
    printf '  sudo '
    printf '%q ' "${compose[@]}"
    printf '%s\n' "$operation"
done
