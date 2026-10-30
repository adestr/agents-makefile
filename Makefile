# Path to the shared workflow file inside your submodule
WORKFLOW_FILE := workflow.md

# Resolve the parent repository root dynamically instead of assuming this
# submodule sits one directory below the repo root. A superproject may be
# absent, so we must check for an actual non-empty value before falling back.
SUPERPROJECT_ROOT := $(shell out=$$(git rev-parse --show-superproject-working-tree 2>/dev/null); if [ -n "$$out" ]; then printf '%s' "$$out"; elif out=$$(git rev-parse --show-toplevel 2>/dev/null); then printf '%s' "$$out"; else printf '%s' "$$(pwd)"; fi)
AGENTS_FILE := $(SUPERPROJECT_ROOT)/AGENTS.md

# Marker boundaries
MARKER_OPEN := <!-- [begin] Evenlode Agentic Workflow [begin] -->
MARKER_CLOSE := <!-- [-end-] Evenlode Agentic Workflow [-end-] -->

.PHONY: workflow health
health:
	@./health-check.sh

workflow:
	@echo "🔄 Syncing workflow into AGENTS.md..."

	@super=$$(git rev-parse --show-superproject-working-tree 2>/dev/null || true); \
	if [ -z "$$super" ]; then \
		echo "❌ This checkout is not a git submodule. Refusing to write $(AGENTS_FILE)."; \
		echo "   From the parent repository: git submodule add https://github.com/adestr/agents-makefile"; \
		exit 1; \
	fi

	@echo "📦 Ensuring workflow is up to date..."
	@# git pull --ff-only

	@if [ ! -f "$(WORKFLOW_FILE)" ]; then \
		echo "❌ Missing $(WORKFLOW_FILE)"; \
		exit 1; \
	fi

	@if [ ! -f "$(AGENTS_FILE)" ]; then \
		echo "📄 Creating AGENTS.md..."; \
		printf '%s\n' "$(MARKER_OPEN)" "$(MARKER_CLOSE)" > $(AGENTS_FILE); \
	fi; \
	ensure_trailing_newline() { \
		file="$$1"; \
		if [ -s "$$file" ] && [ "$$(tail -c 1 "$$file" 2>/dev/null | od -An -t x1 | tr -d ' \n')" != "0a" ]; then \
			printf '\n' >> "$$file"; \
		fi; \
	}; \
	OPEN_COUNT=$$(grep -F -c -x "$(MARKER_OPEN)" $(AGENTS_FILE) || true); \
	CLOSE_COUNT=$$(grep -F -c -x "$(MARKER_CLOSE)" $(AGENTS_FILE) || true); \
	if [ "$$OPEN_COUNT" -ne "$$CLOSE_COUNT" ] || [ "$$OPEN_COUNT" -gt 1 ]; then \
		echo "⚠️  Malformed markers detected — repairing..."; \
		TMP=$$(mktemp); \
		grep -F -v -x -e "$(MARKER_OPEN)" -e "$(MARKER_CLOSE)" $(AGENTS_FILE) > $$TMP || true; \
		ensure_trailing_newline "$$TMP"; \
		printf '%s\n' "$(MARKER_OPEN)" "$(MARKER_CLOSE)" >> $$TMP; \
		mv $$TMP $(AGENTS_FILE); \
	elif [ "$$OPEN_COUNT" -eq 0 ]; then \
		echo "📄 Adding workflow markers..."; \
		ensure_trailing_newline "$(AGENTS_FILE)"; \
		printf '%s\n' "$(MARKER_OPEN)" "$(MARKER_CLOSE)" >> $(AGENTS_FILE); \
	fi

	@echo "✏️  Updating workflow block..."
	@TMP=$$(mktemp); \
	awk -v open="$(MARKER_OPEN)" -v endmarker="$(MARKER_CLOSE)" -v wf="$(WORKFLOW_FILE)" '\
		BEGIN {inblock=0} \
		{ \
			if ($$0 == open) { \
				print $$0; \
				inblock=1; \
				while ((getline line < wf) > 0) print line; \
				close(wf); \
				next; \
			} \
			if ($$0 == endmarker) { \
				inblock=0; \
				print $$0; \
				next; \
			} \
			if (!inblock) print $$0; \
		}' $(AGENTS_FILE) > $$TMP && mv $$TMP $(AGENTS_FILE)

	@echo "✅ Workflow synced successfully."
