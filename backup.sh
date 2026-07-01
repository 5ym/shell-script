#!/bin/sh

set -eu

WORKDIR="/home/ruk"
K3S_DIR="$WORKDIR/k3s"
ARCHIVE_NAME="${1:-backup-$(date +%Y%m%d-%H%M%S).tar.gz}"
REMOTE_PATH="${REMOTE_PATH:-remote:Server/}"
TARGET_NAMESPACES="${TARGET_NAMESPACES:-auth blog epg gitlab portainer xool}"
STATE_FILE="$(mktemp)"
SCALED_DOWN=0
TAB_CHAR="$(printf '\t')"

cleanup() {
	rm -f "$STATE_FILE"
}

restore_replicas() {
	[ "$SCALED_DOWN" -eq 1 ] || return 0

	while IFS="$TAB_CHAR" read -r ns name replicas; do
		[ -n "$ns" ] || continue
		[ -n "$name" ] || continue
			case "$replicas" in
				""|*[!0-9]*) replicas=1 ;;
			esac
		kubectl -n "$ns" scale deploy "$name" --replicas="$replicas" >/dev/null
	done < "$STATE_FILE"
}

finish() {
	restore_replicas
	cleanup
}

trap finish EXIT INT TERM

cd "$WORKDIR"

: > "$STATE_FILE"
for ns in $TARGET_NAMESPACES; do
	kubectl -n "$ns" get deploy \
		-o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.replicas}{"\n"}{end}' \
		>> "$STATE_FILE" 2>/dev/null || true
done

while IFS="$TAB_CHAR" read -r ns name replicas; do
	[ -n "$ns" ] || continue
	[ -n "$name" ] || continue
	case "$replicas" in
		""|*[!0-9]*) replicas=1 ;;
	esac
	[ "$replicas" -eq 0 ] && continue
	kubectl -n "$ns" scale deploy "$name" --replicas=0 >/dev/null
done < "$STATE_FILE"

SCALED_DOWN=1

sudo tar czf "$ARCHIVE_NAME" -C "$WORKDIR" k3s
sudo chown "$(id -u):$(id -g)" "$ARCHIVE_NAME"
chmod 640 "$ARCHIVE_NAME"

# Bring workloads back right after backup is finalized to minimize downtime.
restore_replicas
SCALED_DOWN=0

rclone move -P "$ARCHIVE_NAME" "$REMOTE_PATH"
