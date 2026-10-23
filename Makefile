# Path to the shared workflow file inside your submodule
WORKFLOW_FILE := workflow.md

# AGENTS.md in the parent repository. This checkout must be a submodule
# sitting directly in that repository's working tree.
AGENTS_FILE := ../AGENTS.md

# Marker boundaries
MARKER_OPEN := <!-- [begin] Evenlode Agentic Workflow [begin] -->
MARKER_CLOSE := <!-- [-end-] Evenlode Agentic Workflow [-end-] -->

.PHONY: workflow
workflow:
	@echo "🔄 Syncing workflow into AGENTS.md..."

	@this_top=$$(git rev-parse --show-toplevel 2>/dev/null || true); \
	super=$$(git rev-parse --show-superproject-working-tree 2>/dev/null || true); \
	parent=$$(dirname "$$this_top"); \
	if [ -z "$$super" ]; then \
		echo "❌ This checkout is not a git submodule. Refusing to write ../AGENTS.md."; \
		echo "   From the parent repository: git submodule add https://github.com/adestr/agents-makefile"; \
		exit 1; \
	fi; \
	if [ "$$super" != "$$parent" ]; then \
		echo "❌ This submodule lives in $$super, not directly in that repository's root. Refusing to write ../AGENTS.md."; \
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
	fi

	@OPEN_COUNT=$$(grep -F -c -x "$(MARKER_OPEN)" $(AGENTS_FILE) || true); \
	CLOSE_COUNT=$$(grep -F -c -x "$(MARKER_CLOSE)" $(AGENTS_FILE) || true); \
	if [ "$$OPEN_COUNT" -ne "$$CLOSE_COUNT" ] || [ "$$OPEN_COUNT" -gt 1 ]; then \
		echo "⚠️  Malformed markers detected — repairing..."; \
		TMP=$$(mktemp); \
		grep -F -v -x -e "$(MARKER_OPEN)" -e "$(MARKER_CLOSE)" $(AGENTS_FILE) > $$TMP || true; \
		printf '%s\n' "$(MARKER_OPEN)" "$(MARKER_CLOSE)" >> $$TMP; \
		mv $$TMP $(AGENTS_FILE); \
	elif [ "$$OPEN_COUNT" -eq 0 ]; then \
		echo "📄 Adding workflow markers..."; \
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
