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

## Update

```bash
git submodule update --remote --init --recursive
cd agents-makefile && make workflow
```
