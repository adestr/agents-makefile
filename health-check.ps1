# Reports whether the repository that uses this workflow is set up for it.
# Exit 0: auto-merge eligible. Exit 1: not eligible. Exit 2: the check could not run.
# Native command failures are read from $LASTEXITCODE; Windows PowerShell 5.1 would
# throw on their stderr under ErrorActionPreference Stop.

$Branch = 'main'
$ScriptDir = $PSScriptRoot

$script:eligible = $true
function Pass($message) { Write-Output "PASS  $message" }
function Warn($message) { Write-Output "WARN  $message" }
function Fail($message) { Write-Output "FAIL  $message"; $script:eligible = $false }
function Stop-Check($message) { Write-Output "ERROR $message"; exit 2 }

function Invoke-GhJson([string[]]$ghArgs) {
	$output = & gh @ghArgs 2>$null
	if ($LASTEXITCODE -ne 0) { return $null }
	return ($output -join "`n") | ConvertFrom-Json
}

# Check the superproject when run from inside the submodule, as the Makefile does.
$root = git rev-parse --show-superproject-working-tree 2>$null
if (-not $root) { $root = git rev-parse --show-toplevel 2>$null }
if (-not $root) { Stop-Check 'not inside a git repository' }
Set-Location $root

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Stop-Check 'gh is not installed' }
gh auth status *> $null
if ($LASTEXITCODE -ne 0) { Stop-Check 'gh is not authenticated; run gh auth login' }
$view = Invoke-GhJson @('repo', 'view', '--json', 'nameWithOwner')
if (-not $view) { Stop-Check "no GitHub repository for $root" }
$repo = $view.nameWithOwner
Write-Output "Checking $repo ($Branch)"

$settings = Invoke-GhJson @('api', "repos/$repo")
if (-not $settings) { Stop-Check 'cannot read repository settings' }

$rules = Invoke-GhJson @('api', "repos/$repo/rules/branches/$Branch")
if ($null -eq $rules) { Stop-Check "cannot read rulesets for $Branch" }
$rules = @($rules)
$statusRules = @($rules | Where-Object type -eq 'required_status_checks')
$prRules = @($rules | Where-Object type -eq 'pull_request')

$rsChecks = @($statusRules | ForEach-Object { $_.parameters.required_status_checks }).Count
$rsStrict = @($statusRules | Where-Object { $_.parameters.strict_required_status_checks_policy }).Count -gt 0
$mergeQueue = @($rules | Where-Object type -eq 'merge_queue').Count -gt 0
$copilot = @($rules | Where-Object type -eq 'copilot_code_review').Count -gt 0
$threadResolution = @($prRules | Where-Object { $_.parameters.required_review_thread_resolution }).Count -gt 0
$rsNoSquash = @($prRules | Where-Object { $_.parameters.allowed_merge_methods -and ($_.parameters.allowed_merge_methods -notcontains 'squash') }).Count -gt 0
$approvals = ($prRules | ForEach-Object { $_.parameters.required_approving_review_count } | Measure-Object -Maximum).Maximum
if (-not $approvals) { $approvals = 0 }

$branchInfo = Invoke-GhJson @('api', "repos/$repo/branches/$Branch")
if (-not $branchInfo) { Stop-Check "cannot read branch $Branch" }
$classic = $branchInfo.protection.required_status_checks
$classicChecks = [Math]::Max(@($classic.checks | Where-Object { $_ }).Count, @($classic.contexts | Where-Object { $_ }).Count)
# Reading classic protection needs admin rights; treat an unreadable policy as not strict.
$classicPolicy = Invoke-GhJson @('api', "repos/$repo/branches/$Branch/protection/required_status_checks")
$classicStrict = [bool]($classicPolicy -and $classicPolicy.strict)

if ($settings.allow_auto_merge) { Pass 'auto-merge is allowed' }
else { Fail 'auto-merge is not allowed (Settings > General > Allow auto-merge)' }

if ($settings.allow_squash_merge -and -not $rsNoSquash) { Pass 'squash merge is allowed' }
else { Fail "squash merge is not allowed for $Branch" }

$requiredChecks = $rsChecks + $classicChecks
if ($requiredChecks -gt 0) { Pass "$Branch has $requiredChecks required status check(s)" }
else { Fail "$Branch has no required status checks, so auto-merge would merge without CI" }

if ($rsStrict -or $mergeQueue -or $classicStrict) { Pass "PRs must be up to date with $Branch, or merge through a queue" }
else { Warn "PRs need not be up to date with $Branch; two green PRs can break it together" }

if ($copilot -and -not $threadResolution) {
	Warn 'Copilot review does not block merging; enable required conversation resolution to make it'
}

if ($approvals -gt 0) { Warn "auto-merge also waits for $approvals approving review(s)" }

$workflows = @(Get-ChildItem -Path '.github/workflows' -File -ErrorAction SilentlyContinue |
	Where-Object { $_.Extension -in '.yml', '.yaml' })
if ($workflows.Count -gt 0) { Pass 'GitHub Actions workflows found' }
else { Warn 'no .github/workflows; required checks must come from another CI' }

$makefile = Get-Content (Join-Path $ScriptDir 'Makefile')
$markerOpen = ($makefile | Select-String -Pattern '^MARKER_OPEN := (.*)$').Matches[0].Groups[1].Value
$markerClose = ($makefile | Select-String -Pattern '^MARKER_CLOSE := (.*)$').Matches[0].Groups[1].Value
$agents = if (Test-Path AGENTS.md) { @(Get-Content AGENTS.md) } else { @() }
if ($agents -notcontains $markerOpen) {
	Warn "AGENTS.md has no workflow block; run make workflow in $(Split-Path $ScriptDir -Leaf)"
}
else {
	$inBlock = $false
	$notes = $false
	foreach ($line in $agents) {
		if ($line -ceq $markerOpen) { $inBlock = $true; continue }
		if ($line -ceq $markerClose) { $inBlock = $false; continue }
		if (-not $inBlock -and $line.Trim()) { $notes = $true }
	}
	if ($notes) { Pass 'AGENTS.md has the workflow block and repository notes' }
	else { Warn 'AGENTS.md records nothing outside the workflow block, so adversarial-review has no boundaries to check' }
}

if ($script:eligible) {
	Write-Output 'auto-merge: eligible'
	exit 0
}
Write-Output 'auto-merge: not eligible'
exit 1
