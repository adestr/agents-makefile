# Agents Makefile

An agentic workflow using a directed acyclic graph, defined using Makefile syntax, along with a Makefile to allow synchronisation of the workflow into your repository's AGENTS.md.

The workflow is defined in [workflow.md](./workflow.md).

The makefile looks for placeholder tags which mark the start and end of the workflow in your AGENTS.md, then inserts the latest workflow between those tags. If the tags do not exist, they will be created. If the tags exist, but are malformed, then any pre-existing tags will be removed _but the content between the tags will not be stripped out_.

> It is **your responsibility** to ensure that your AGENTS.md does not contain a duplicate workflow if malformed tags were detected.

## Setup

```bash
git submodule add https://github.com/adestr/agents-makefile
cd agents-makefile && make workflow
```

After `make workflow`, document this repository's boundaries in `AGENTS.md`, outside the workflow markers. The adversarial review treats coupling across a recorded boundary as a blocker when the plan did not name it. If you record no boundary, that check does not apply.

## Health check

```bash
cd agents-makefile && make health
```

`health-check.sh` (or `health-check.ps1` on Windows) reads the GitHub settings of the parent repository through `gh` and reports setup the workflow relies on: auto-merge and squash merge allowed, required status checks on `main`, an up-to-date or merge-queue policy, whether bot reviews can block merging, and whether `AGENTS.md` holds the workflow block and repository notes. Each finding is `PASS`, `WARN`, or `FAIL`.

The last line is `auto-merge: eligible` (exit 0) or `auto-merge: not eligible` (exit 1); exit 2 means the check could not run. The workflow runs it at the start of each ticket, and offers `ship` at commit time only when the repository is eligible. `ship` commits, pushes, opens the pull request, and enables auto-merge after bot reviews are triaged. A later run picks up any auto-merge pull request whose checks fail, conflicts, or receives a new bot review, before starting the next ticket.

## Update

```bash
git submodule update --remote --init --recursive
cd agents-makefile && make workflow
```
