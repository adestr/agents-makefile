#!/usr/bin/env bash
# Reports whether the repository that uses this workflow is set up for it.
# Exit 0: auto-merge eligible. Exit 1: not eligible. Exit 2: the check could not run.
set -u

BRANCH=main
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

eligible=1
pass() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; eligible=0; }
error() { printf 'ERROR %s\n' "$1"; exit 2; }

# Check the superproject when run from inside the submodule, as the Makefile does.
root=$(git rev-parse --show-superproject-working-tree 2>/dev/null)
[ -n "$root" ] || root=$(git rev-parse --show-toplevel 2>/dev/null) || error "not inside a git repository"
cd "$root" || error "cannot enter $root"

command -v gh >/dev/null 2>&1 || error "gh is not installed"
gh auth status >/dev/null 2>&1 || error "gh is not authenticated; run gh auth login"
repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) || error "no GitHub repository for $root"
echo "Checking $repo ($BRANCH)"

read -r allow_auto allow_squash < <(gh api "repos/$repo" --jq '[.allow_auto_merge, .allow_squash_merge] | @tsv') \
	|| error "cannot read repository settings"

read -r rs_checks rs_strict merge_queue copilot thread_resolution rs_no_squash approvals < <(
	gh api "repos/$repo/rules/branches/$BRANCH" --jq '[
		([.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[]] | length),
		any(.[]; .type == "required_status_checks" and .parameters.strict_required_status_checks_policy),
		any(.[]; .type == "merge_queue"),
		any(.[]; .type == "copilot_code_review"),
		any(.[]; .type == "pull_request" and .parameters.required_review_thread_resolution),
		any(.[]; .type == "pull_request" and ((.parameters.allowed_merge_methods // ["squash"]) | index("squash") == null)),
		([.[] | select(.type == "pull_request") | .parameters.required_approving_review_count] | max // 0)
	] | @tsv') || error "cannot read rulesets for $BRANCH"

classic_checks=$(gh api "repos/$repo/branches/$BRANCH" \
	--jq '[(.protection.required_status_checks.checks // [] | length), (.protection.required_status_checks.contexts // [] | length)] | max') \
	|| error "cannot read branch $BRANCH"
# Reading classic protection needs admin rights; treat an unreadable policy as not strict.
classic_strict=$(gh api "repos/$repo/branches/$BRANCH/protection/required_status_checks" --jq .strict 2>/dev/null) || classic_strict=false

if [ "$allow_auto" = true ]; then pass "auto-merge is allowed"; else fail "auto-merge is not allowed (Settings > General > Allow auto-merge)"; fi

if [ "$allow_squash" = true ] && [ "$rs_no_squash" = false ]; then
	pass "squash merge is allowed"
else
	fail "squash merge is not allowed for $BRANCH"
fi

if [ $((rs_checks + classic_checks)) -gt 0 ]; then
	pass "$BRANCH has $((rs_checks + classic_checks)) required status check(s)"
else
	fail "$BRANCH has no required status checks, so auto-merge would merge without CI"
fi

if [ "$rs_strict" = true ] || [ "$merge_queue" = true ] || [ "$classic_strict" = true ]; then
	pass "PRs must be up to date with $BRANCH, or merge through a queue"
else
	warn "PRs need not be up to date with $BRANCH; two green PRs can break it together"
fi

if [ "$copilot" = true ] && [ "$thread_resolution" = false ]; then
	warn "Copilot review does not block merging; enable required conversation resolution to make it"
fi

if [ "$approvals" -gt 0 ]; then
	warn "auto-merge also waits for $approvals approving review(s)"
fi

if compgen -G ".github/workflows/*.y*ml" >/dev/null; then
	pass "GitHub Actions workflows found"
else
	warn "no .github/workflows; required checks must come from another CI"
fi

marker=$(sed -n 's/^MARKER_OPEN := //p' "$SCRIPT_DIR/Makefile")
if [ ! -f AGENTS.md ] || ! grep -Fqx "$marker" AGENTS.md; then
	warn "AGENTS.md has no workflow block; run make workflow in $(basename "$SCRIPT_DIR")"
elif ! awk -v open="$marker" -v close="$(sed -n 's/^MARKER_CLOSE := //p' "$SCRIPT_DIR/Makefile")" '
		$0 == open { inblock = 1; next }
		$0 == close { inblock = 0; next }
		!inblock && NF { found = 1 }
		END { exit !found }' AGENTS.md; then
	warn "AGENTS.md records nothing outside the workflow block, so adversarial-review has no boundaries to check"
else
	pass "AGENTS.md has the workflow block and repository notes"
fi

if [ "$eligible" -eq 1 ]; then
	echo "auto-merge: eligible"
	exit 0
fi
echo "auto-merge: not eligible"
exit 1
