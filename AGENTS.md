# Agent Workflow

The workflow is a Makefile-style DAG. The active target is `finish` unless the human names another target from this file.

1. Start at the active target. Choose its leftmost prerequisite that is not satisfied, and repeat until every prerequisite of the current target is satisfied. Work on that target.
2. Run that target's recipe. When it is satisfied, write the name of the current target in inline code, then ' → ', then the name of the leftmost unsatisfied target, and continue to that leftmost unsatisfied target in the same turn.
   - Stop only when the next target is named `human-*-approval`, or when the stage just finished makes an earlier gate unsatisfied. `triaged-blockers` and `all-bots-triaged` name that backward move.
   - On a human gate, ask for the approval that gate's **Satisfied when** line requires. Do not treat "Continue" as that approval.
3. A target is satisfied only when its **Satisfied when** condition is true.
4. A human gate is satisfied only when the human's latest message explicitly approves the artifact that gate presented. Approval of a different gate does not count. If the human asks for a change, that gate is unsatisfied and the target that produced the artifact is unsatisfied too.
5. Do not add a target, skip a target, or choose a different unsatisfied prerequisite than the leftmost one.
6. Lines under a target are instructions. A line in backticks is a command.
7. Do not commit, push, merge, check out another branch, or delete branches except where `branch-created`, `commit`, `push`, `land`, or `pristine-workbench` says to.
8. If a recipe says a scar ledger, changelog, CI workflow, or review bot is absent, record that and finish the step. Do not create that system in order to satisfy the step.

Coding practice is enforced by `tdd-failing-repro`, `implementation-diff`, `adversarial-review`, and `clean-static-analysis`.

## Workflow

```makefile
.PHONY: finish pristine-workbench codified-scars-consolidated land \
	human-landing-approval ready-to-land ci-quiescent changelog-updated \
	ci-remote-green all-bots-triaged push human-push-approval commit \
	human-commit-approval pre-commit-clean approved-adversarial-report \
	clean-static-analysis doc-audit-complete human-review-approval \
	triaged-blockers adversarial-review human-diff-approval \
	implementation-diff tdd-failing-repro approved-plan human-plan-approval \
	researched-ticket branch-created candidate-scars git-archaeology ticket-assigned

finish: pristine-workbench
pristine-workbench: codified-scars-consolidated
codified-scars-consolidated: land
land: human-landing-approval
human-landing-approval: ready-to-land
ready-to-land: ci-quiescent changelog-updated
ci-quiescent: ci-remote-green all-bots-triaged
ci-remote-green: push
all-bots-triaged: push
push: human-push-approval
human-push-approval: commit
commit: human-commit-approval
human-commit-approval: pre-commit-clean
pre-commit-clean: approved-adversarial-report clean-static-analysis doc-audit-complete
approved-adversarial-report: human-review-approval
human-review-approval: triaged-blockers
triaged-blockers: adversarial-review
adversarial-review: human-diff-approval
human-diff-approval: implementation-diff
implementation-diff: tdd-failing-repro
tdd-failing-repro: approved-plan
approved-plan: human-plan-approval
human-plan-approval: researched-ticket
researched-ticket: branch-created candidate-scars git-archaeology
branch-created: ticket-assigned
candidate-scars: branch-created
git-archaeology: branch-created
clean-static-analysis: human-diff-approval
doc-audit-complete: human-diff-approval
changelog-updated: human-diff-approval
ticket-assigned:
```

## Workflow Steps

```makefile
ticket-assigned:
	Restate the human's requested outcome in one sentence, including what will be different when the work is done.
	The human's message is the ticket when it names that outcome. Do not invent a tracker id.
	Satisfied when: that sentence is stated and it matches the human's request.

branch-created:
	Name the working branch `[prefix]/[issue number]-[terse kebab-case issue summary]`.
	Use the prefix `fix` when the issue is labelled `bug`, and `feat` otherwise.
	Take the issue number, title, and labels from the issue the human named. Do not invent an issue number.
	If the current branch already has that name, stop.
	If that branch exists, check it out.
	Otherwise check out `main`, run `git pull`, and create the branch from `main`.
	Satisfied when: `git branch --show-current` prints that name.

candidate-scars:
	Search the repository for a scar ledger: a file that records entries in the form WOUND, TRAP, REFLEX.
	If a ledger exists, quote each entry whose subject is the area named by the ticket.
	If no ledger exists, say "no scar ledger" and stop. Do not create one.
	Satisfied when: the quoted entries are listed, or "no scar ledger" is stated.

git-archaeology:
	From the repository root, run `git log -20 --oneline -- <paths>` for the paths the ticket will change.
	Read the commits that explain the current behavior. Use `git blame` on a line only when the log does not show who last set that behavior.
	Satisfied when: the notes name those paths and what the current behavior is, with the commit subjects that establish it.

researched-ticket:
	Write the research note: the ticket sentence, the scar result, and the archaeology result.
	State the constraints you found in the code you read. Do not edit the tree.
	Satisfied when: the note includes all three inputs and those constraints.

human-plan-approval:
	Present the plan that follows from the research note. Include the files to change, the behavior change, the test that will prove it, and the work you will not do.
	Stop and ask the human to accept this plan.
	Satisfied when: the human's latest message explicitly accepts that plan.

approved-plan:
	Restate the plan the human accepted. Do not widen it.
	Satisfied when: the restated plan is the accepted one.
	If the plan must change, `human-plan-approval` is unsatisfied until the human accepts the revised plan.

tdd-failing-repro:
	If the accepted plan changes runtime behavior, add a test that fails because that behavior is missing. Do not edit production code in this step.
	Run the narrowest existing command that executes that test: `dotnet test` from `instrumentation/` for C# tests, or `pnpm test` from `ui/` for panel tests.
	Show the failing assertion.
	If the accepted plan changes no runtime behavior, add no test. Say "no runtime behavior; no test added".
	Satisfied when: the new test's failure output is shown, or "no runtime behavior; no test added" is stated.

implementation-diff:
	Change only the files named in the accepted plan, and only enough to make the failing test pass or to apply the docs-only plan.
	Keep one source for each rule. Take new dependencies from existing constructors or parameters. Do not add a type, parameter, or wrapper the plan does not use.
	Run the same test command as `tdd-failing-repro` when a test was added, and show it passing.
	Show `git diff`. Do not commit.
	Satisfied when: the diff matches the accepted plan and the new test passes, or the docs-only diff is shown.

human-diff-approval:
	Present `git diff` and a short summary of what changed.
	Stop and ask the human to approve this diff.
	Satisfied when: the human's latest message explicitly approves that diff.
	Any later edit to the diff makes this gate unsatisfied.

adversarial-review:
	Review the approved diff. Report each finding as `blocker` or `note`, with the file, the principle, what is wrong, and the change that would clear it.
	A `blocker` is required when any of these is true:
	- SRP: a type touched by the diff has a second reason to change, and the plan did not ask to combine those reasons.
	- OCP: the diff adds a conditional to an existing type when an interface already exists for that variation.
	- LSP: a subtype changes behavior so an existing caller of the base type would be wrong.
	- ISP: a new or widened interface has a member its callers in the diff do not use.
	- DIP: a unit constructs a concrete collaborator that its caller already supplies.
	- DRY: the diff copies a rule, mapping, or literal that already has one definition in the repository.
	- YAGNI: the diff adds a type, parameter, or layer the accepted plan does not exercise.
	- KISS: the diff adds an indirection that only forwards to one callee.
	- Errors: a failure is ignored, logged and then treated as success, or returned as a success value.
	- Tests: runtime behavior changed and removing that behavior would not fail a test.
	- Scope: the diff changes a file or behavior the accepted plan did not name.
	- Boundaries: the page hook (`inject.js` and `window.__BLAZOR_WASM_DEVTOOLS_GLOBAL_HOOK__`), the extension UI (`ui/`), or the NuGet instrumentation (`instrumentation/`) are coupled in a way the plan did not name.
	A `note` is a naming or wording issue that no check in `clean-static-analysis` enforces. Do not edit the diff to clear a note.
	If nothing matches, the report is `no findings`.
	Satisfied when: the report is shown.

triaged-blockers:
	For each `blocker`, either fix it in the diff or ask the human to defer it.
	A fix is a diff edit, so `human-diff-approval` and `adversarial-review` become unsatisfied. Repeat them before continuing.
	A deferral counts only when the human's latest message explicitly defers that blocker.
	Leave every `note` unfixed.
	Satisfied when: every blocker is fixed and re-reviewed, or explicitly deferred, and `no findings` or only `note`s remain.

human-review-approval:
	Present the adversarial report and the triage result.
	Stop and ask the human to approve the adversarial report and the triage result.
	Satisfied when: the human's latest message explicitly approves the adversarial report and the triage result.

approved-adversarial-report:
	Restate the approved report and the disposition of each blocker.
	Satisfied when: that restatement matches what the human approved.

clean-static-analysis:
	Run only the checks for files in the approved diff.
	If the diff includes `*.cs` or `*.csproj`, run `dotnet test` from `instrumentation/`.
	If the diff includes files under `ui/`, run `pnpm lint` from the repository root.
	If the diff includes neither, say "no code files; no static check".
	Satisfied when: each command you were required to run exited 0, or "no code files; no static check" is stated.

doc-audit-complete:
	Read `README.md`, `instrumentation/README.md`, and `ui/README.md`.
	If the approved diff changes behavior that one of those files already describes, update that file so the description matches the diff.
	If none of them describe the changed behavior, say which files you read and that none describe it. Do not add a new document.
	Satisfied when: those descriptions match the diff, or you have stated that none of them cover it.

pre-commit-clean:
	Run `git status` and `git diff`.
	Confirm the tree contains only the approved diff, the test from `tdd-failing-repro`, doc fixes from `doc-audit-complete`, and blocker fixes.
	Satisfied when: that is all `git status` shows, and `clean-static-analysis` and `doc-audit-complete` are satisfied.

human-commit-approval:
	Show `git status` and the proposed commit message. The message states why the change was made.
	Stop and ask the human for permission to create the commit.
	Satisfied when: the human's latest message explicitly tells you to create the commit.

commit:
	Stage only the files that belong in the approved diff and create the commit with the approved message.
	Satisfied when: `git status` is clean and `git log -1` is that commit.

human-push-approval:
	State the remote and branch you will push.
	Stop and ask the human for permission to push.
	Satisfied when: the human's latest message explicitly tells you to push.

push:
	Run `git push -u origin HEAD`.
	Satisfied when: the command exited 0 and the remote branch contains the commit from `commit`.

ci-remote-green:
	If the remote has required checks for the branch, wait until each required check has succeeded.
	If `.github/workflows/` has no workflow files, or the branch has no checks, say "no remote CI checks".
	Satisfied when: every required check has succeeded, or "no remote CI checks" is stated.

all-bots-triaged:
	If a pull request exists and a bot review has been requested but not submitted, wait until that review is submitted. Do not say "no bot comments" while that request is outstanding.
	If a pull request exists, read each review comment left by a bot.
	For each comment, either fix it or record a one-line reason it is deferred. A fix makes `human-diff-approval` unsatisfied; repeat from that gate.
	If there is no pull request, or no bot comments, say "no bot comments".
	Satisfied when: no requested bot review is still outstanding, and every bot comment is fixed or has a recorded deferral, or "no bot comments" is stated.

ci-quiescent:
	Satisfied when: `ci-remote-green` and `all-bots-triaged` are satisfied. Do nothing else.

changelog-updated:
	If a changelog file exists, add an entry for each user-visible change in the approved diff.
	If no changelog file exists, put those user-visible changes in the commit message from `commit`. Do not create a changelog file.
	If the diff has no user-visible change, say "no user-visible change".
	Satisfied when: the entry exists, the commit message already states the user-visible change, or "no user-visible change" is stated.

ready-to-land:
	State how you will land: the pull request to open or update, and the base branch `main`.
	Do not open or merge it in this step.
	Satisfied when: `ci-quiescent` and `changelog-updated` are satisfied and that landing statement is shown.

human-landing-approval:
	Present the landing statement from `ready-to-land`.
	Stop and ask the human to approve landing onto `main`.
	Satisfied when: the human's latest message explicitly approves landing onto `main`.

land:
	Open or update the pull request. Include `Closes #[id]` in the body, where `[id]` is the issue number the human named.
	If this step opened the pull request, run `sleep 5` before checking for review requests, so an automatic request has time to appear.
	Apply `all-bots-triaged` to that pull request. Do not merge while it is unsatisfied.
	Then merge the pull request into `main` using the path the human approved.
	Satisfied when: the commit from `commit` is contained in `main`, or the pull request into `main` has been merged by squash or rebase, and every bot comment that was present before the merge was fixed or deferred.

codified-scars-consolidated:
	This step records a new failure mode from the work just finished. It does not introduce a scar practice into a repository that has none.
	If you hit no new failure mode during this change, say "no new scar".
	A failure mode is a crash, a wrong result, a flaky test, corrupted output, or a review miss that escaped `adversarial-review`.
	If you hit one and a scar ledger exists, append one entry:
	- WOUND: the observed failure
	- TRAP: the shortcut that produced it
	- REFLEX: the check that prevents repeating it
	If you hit one and no scar ledger exists, write those three lines in the turn only. Do not add a ledger file.
	Satisfied when: "no new scar" is stated, or the WOUND, TRAP, and REFLEX lines are written to the existing ledger or to the turn.

pristine-workbench:
	Run `git checkout main` and `git pull`.
	For every local branch other than `main`, run `git checkout --detach <branch>` and `git rebase main`.
	If the rebase fails, run `git rebase --abort` and keep the branch.
	If the rebase succeeds and `git merge-base --is-ancestor HEAD main` succeeds, run `git checkout main` and delete that branch with `git branch -D <branch>`.
	If `HEAD` is ahead of `main`, run `git checkout main` and leave the branch ref as it was.
	Never delete `main`.
	Satisfied when: `main` is checked out, it matches its remote, and every deleted branch was proven by that rebase to contain no commits outside `main`.

finish:
	Satisfied when: `pristine-workbench` is satisfied. Do nothing else.
```
