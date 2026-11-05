#!/usr/bin/env bash
# Sync the Evenlode agentic workflow into a target repository.
#
# Bootstrap or update from a target repo root:
#   curl -fsSL https://raw.githubusercontent.com/adestr/agents-makefile/main/sync.sh | bash
#
# Or, after the first sync, from the target repo:
#   ./.agents-makefile/sync.sh
#
# From this (canonical) checkout, sync a specific repo:
#   ./sync.sh /path/to/target-repo
#
# Optional env:
#   AGENTS_MAKEFILE_REPO  GitHub owner/name (default: adestr/agents-makefile)
#   AGENTS_MAKEFILE_REF   git ref for raw fetches (default: main)
set -euo pipefail

SOURCE_REPO="${AGENTS_MAKEFILE_REPO:-adestr/agents-makefile}"
REF="${AGENTS_MAKEFILE_REF:-main}"
VENDOR_DIR=".agents-makefile"
RAW_BASE="https://raw.githubusercontent.com/${SOURCE_REPO}/${REF}"

MARKER_OPEN='<!-- [begin] Evenlode Agentic Workflow [begin] -->'
MARKER_CLOSE='<!-- [-end-] Evenlode Agentic Workflow [-end-] -->'

VENDOR_FILES=(sync.sh health-check.sh health-check.ps1 workflow.md)

die() { printf '❌ %s\n' "$1" >&2; exit 1; }
info() { printf '%s\n' "$1"; }

# The canonical checkout keeps Makefile beside sync.sh; vendored copies do not.
is_canonical_layout() {
	local root=$1
	[[ -f "$root/workflow.md" && -f "$root/sync.sh" && -f "$root/Makefile" ]]
}

script_dir() {
	if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
		cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
	else
		return 1
	fi
}

# When this file lives on disk in the canonical checkout, prefer those files over the network.
resolve_local_source() {
	local here candidate
	here=$(script_dir) || return 1
	if is_canonical_layout "$here"; then
		printf '%s' "$here"
		return 0
	fi
	candidate=$(cd "$here/.." && pwd)
	if is_canonical_layout "$candidate"; then
		printf '%s' "$candidate"
		return 0
	fi
	return 1
}

# When invoked as <repo>/.agents-makefile/sync.sh, the target is <repo>.
resolve_vendored_target() {
	local here parent
	here=$(script_dir) || return 1
	if [[ "$(basename "$here")" == "$VENDOR_DIR" ]]; then
		parent=$(cd "$here/.." && pwd)
		if ! is_canonical_layout "$parent"; then
			printf '%s' "$parent"
			return 0
		fi
	fi
	return 1
}

fetch_to() {
	# fetch_to <relative-path> <dest-file>
	local rel=$1 dest=$2
	if [[ -n "$LOCAL_SOURCE" && -f "$LOCAL_SOURCE/$rel" ]]; then
		cp "$LOCAL_SOURCE/$rel" "$dest"
		return 0
	fi
	if command -v curl >/dev/null 2>&1 \
		&& curl -fsSL "$RAW_BASE/$rel" -o "$dest" 2>/dev/null; then
		return 0
	fi
	# Offline / unpublished-ref fallback: reuse a previously vendored copy.
	if [[ -f "$TARGET_ROOT/$VENDOR_DIR/$rel" ]]; then
		info "⚠️  Could not download $rel; reusing $VENDOR_DIR/$rel"
		cp "$TARGET_ROOT/$VENDOR_DIR/$rel" "$dest"
		return 0
	fi
	if ! command -v curl >/dev/null 2>&1; then
		die "curl is required to fetch $rel (no local or vendored copy available)"
	fi
	die "failed to download $RAW_BASE/$rel"
}

ensure_trailing_newline() {
	local file=$1
	if [[ -s "$file" ]] && [[ "$(tail -c 1 "$file" | od -An -t x1 | tr -d ' \n')" != "0a" ]]; then
		printf '\n' >>"$file"
	fi
}

splice_agents() {
	local agents_file=$1 workflow_file=$2
	local open_count close_count tmp

	if [[ ! -f "$agents_file" ]]; then
		info "📄 Creating AGENTS.md..."
		printf '%s\n' "$MARKER_OPEN" "$MARKER_CLOSE" >"$agents_file"
	fi

	open_count=$(grep -F -c -x "$MARKER_OPEN" "$agents_file" || true)
	close_count=$(grep -F -c -x "$MARKER_CLOSE" "$agents_file" || true)

	if [[ "$open_count" -ne "$close_count" ]] || [[ "$open_count" -gt 1 ]]; then
		info "⚠️  Malformed markers detected — repairing..."
		tmp=$(mktemp)
		grep -F -v -x -e "$MARKER_OPEN" -e "$MARKER_CLOSE" "$agents_file" >"$tmp" || true
		ensure_trailing_newline "$tmp"
		printf '%s\n' "$MARKER_OPEN" "$MARKER_CLOSE" >>"$tmp"
		mv "$tmp" "$agents_file"
	elif [[ "$open_count" -eq 0 ]]; then
		info "📄 Adding workflow markers..."
		ensure_trailing_newline "$agents_file"
		printf '%s\n' "$MARKER_OPEN" "$MARKER_CLOSE" >>"$agents_file"
	fi

	info "✏️  Updating workflow block..."
	tmp=$(mktemp)
	awk -v open="$MARKER_OPEN" -v endmarker="$MARKER_CLOSE" -v wf="$workflow_file" '
		BEGIN { inblock = 0 }
		{
			if ($0 == open) {
				print $0
				inblock = 1
				while ((getline line < wf) > 0) print line
				close(wf)
				next
			}
			if ($0 == endmarker) {
				inblock = 0
				print $0
				next
			}
			if (!inblock) print $0
		}
	' "$agents_file" >"$tmp" && mv "$tmp" "$agents_file"
}

# --- resolve target ----------------------------------------------------------

LOCAL_SOURCE=""
if LOCAL_SOURCE=$(resolve_local_source); then
	:
else
	LOCAL_SOURCE=""
fi

TARGET_ROOT=""
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	sed -n '2,16p' "${BASH_SOURCE[0]:-/dev/stdin}" 2>/dev/null || true
	exit 0
fi

if [[ -n "${1:-}" ]]; then
	# Resolve the enclosing git root so a subdirectory path still syncs the repo.
	TARGET_ROOT=$(cd "$1" && git rev-parse --show-toplevel 2>/dev/null) \
		|| die "target path is not inside a git repository: $1"
elif TARGET_ROOT=$(resolve_vendored_target); then
	:
else
	TARGET_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) \
		|| die "not inside a git repository; cd to the target repo or pass its path"
fi

if is_canonical_layout "$TARGET_ROOT"; then
	die "refusing to sync into the agents-makefile source repo itself; pass a target path (./sync.sh /path/to/repo)"
fi

command -v awk >/dev/null 2>&1 || die "awk is required"

info "🔄 Syncing workflow into $TARGET_ROOT ..."
if [[ -n "$LOCAL_SOURCE" ]]; then
	info "📦 Using local source: $LOCAL_SOURCE"
else
	info "📦 Fetching from $SOURCE_REPO@$REF"
fi

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

for f in "${VENDOR_FILES[@]}"; do
	fetch_to "$f" "$STAGE/$f"
done

splice_agents "$TARGET_ROOT/AGENTS.md" "$STAGE/workflow.md"

# Install vendored copies last so overwriting a running sync.sh cannot truncate this process.
VENDOR_PATH="$TARGET_ROOT/$VENDOR_DIR"
mkdir -p "$VENDOR_PATH"
for f in "${VENDOR_FILES[@]}"; do
	cp "$STAGE/$f" "$VENDOR_PATH/$f"
	case "$f" in
		*.sh) chmod +x "$VENDOR_PATH/$f" ;;
	esac
done

info "✅ Workflow synced successfully."
info "   Vendored: $VENDOR_DIR/{${VENDOR_FILES[*]}}"
info "   Updated:  AGENTS.md"
info "   Commit these files in the target repository."
info "   Later updates: $VENDOR_DIR/sync.sh"
