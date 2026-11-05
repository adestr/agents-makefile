# Thin wrappers around sync.sh / health-check.sh.
# Prefer the curl-based flow documented in README.md; submodule installs are legacy.

.PHONY: workflow health

health:
	@./health-check.sh

# Sync into a target repository.
#   make workflow TARGET=/path/to/repo
# When run from a git submodule without TARGET, syncs the superproject.
workflow:
	@target="$(TARGET)"; \
	if [ -z "$$target" ]; then \
		target=$$(git rev-parse --show-superproject-working-tree 2>/dev/null || true); \
	fi; \
	if [ -z "$$target" ]; then \
		echo "❌ Pass TARGET=/path/to/repo, or run from a submodule / use sync.sh directly."; \
		echo "   curl -fsSL https://raw.githubusercontent.com/adestr/agents-makefile/main/sync.sh | bash"; \
		exit 1; \
	fi; \
	./sync.sh "$$target"
