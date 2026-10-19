#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
installer="$repo_dir/scripts/setup-relay.sh"
test_dir=$(mktemp -d)
trap 'rm -r -- "$test_dir"' EXIT

bash -n "$installer"
bash "$installer" --help > "$test_dir/help"
grep -q -- '--render-only' "$test_dir/help"

bash "$installer" --host relay.example.com --dir "$test_dir/not-created" --render-only > "$test_dir/compose.yaml"
[[ ! -e $test_dir/not-created ]]
grep -q 'relay.example.com:21117' "$test_dir/compose.yaml"
if grep -q '\${RELAY_HOST' "$test_dir/compose.yaml"; then exit 1; fi
if command -v docker-compose >/dev/null 2>&1; then
    docker-compose -f "$test_dir/compose.yaml" config --quiet
elif docker compose version >/dev/null 2>&1; then
    docker compose -f "$test_dir/compose.yaml" config --quiet
fi

for invalid in '' 'https://relay.example.com' 'relay.example.com:21117' 'bad host' '$(touch /tmp/lanterndesk-test)' '..'; do
    if bash "$installer" --host "$invalid" --render-only > /dev/null 2>&1; then
        printf 'Unexpectedly accepted invalid host: %s\n' "$invalid" >&2
        exit 1
    fi
done
if bash "$installer" --host > /dev/null 2>&1; then exit 1; fi
printf 'PASS: relay CLI, side-effect-free rendering, and invalid host rejection\n'
