# Agents Makefile

An agentic workflow using a directed acyclic graph, defined using Makefile syntax, plus a small sync script that vendors the helpers into your repository and splices the workflow into `AGENTS.md`.

The workflow is defined in [workflow.md](./workflow.md).

## Setup

From your target repository root (no submodule required):

```bash
curl -fsSL https://raw.githubusercontent.com/adestr/agents-makefile/main/sync.sh | bash
```

That will:

1. Create `.agents-makefile/` with `sync.sh`, `health-check.sh`, `health-check.ps1`, and `workflow.md`
2. Insert or refresh the workflow block in `AGENTS.md` between the Evenlode markers

Commit those files. After the first sync, prefer the vendored script so you do not need to remember the curl URL:

```bash
./.agents-makefile/sync.sh
```

The sync script looks for placeholder tags that mark the start and end of the workflow in your `AGENTS.md`, then inserts the latest workflow between those tags. If the tags do not exist, they will be created. If the tags exist but are malformed, any pre-existing tags will be removed _but the content between the tags will not be stripped out_.

> It is **your responsibility** to ensure that your `AGENTS.md` does not contain a duplicate workflow if malformed tags were detected.

After syncing, document this repository's boundaries in `AGENTS.md`, outside the workflow markers. The adversarial review treats coupling across a recorded boundary as a blocker when the plan did not name it. If you record no boundary, that check does not apply. The workflow reads its scar ledger from `SCARS.md` at the repository root; to use another file, name its path as the scar ledger in `AGENTS.md`, outside the workflow markers.

### Sync from this checkout

If you have this repository cloned locally:

```bash
./sync.sh /path/to/your-repo
# or: make workflow TARGET=/path/to/your-repo
```

Optional environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `AGENTS_MAKEFILE_REPO` | `adestr/agents-makefile` | GitHub `owner/name` for raw downloads |
| `AGENTS_MAKEFILE_REF` | `main` | Git ref to fetch |

## Health check

```bash
./.agents-makefile/health-check.sh
# Windows: .\.agents-makefile\health-check.ps1
```

From this repository's checkout you can also run `make health`.

`health-check.sh` (or `health-check.ps1` on Windows) reads the GitHub settings of the repository through `gh` and reports setup the workflow relies on: auto-merge and squash merge allowed, required status checks on `main`, an up-to-date or merge-queue policy, whether bot reviews can block merging, and whether `AGENTS.md` holds the workflow block and repository notes. Each finding is `PASS`, `WARN`, or `FAIL`.

The last line is `auto-merge: eligible` (exit 0) or `auto-merge: not eligible` (exit 1); exit 2 means the check could not run. The workflow runs it at the start of each ticket, and offers `ship` at commit time only when the repository is eligible. `ship` commits, pushes, opens the pull request, and enables auto-merge after bot reviews are triaged. A later run picks up any auto-merge pull request whose checks fail, conflicts, or receives a new bot review, before starting the next ticket.

## Update

From the target repository:

```bash
./.agents-makefile/sync.sh
```

Or again via curl:

```bash
curl -fsSL https://raw.githubusercontent.com/adestr/agents-makefile/main/sync.sh | bash
```

Then commit the refreshed `.agents-makefile/` files and `AGENTS.md`.

## Legacy submodule installs

Older setups added this repository as a git submodule and ran `make workflow` inside it. That still works when the checkout is a submodule (`make workflow` syncs the superproject and vendors into `.agents-makefile/`). New repos should use the curl flow above and can remove the submodule after a successful sync and commit.
