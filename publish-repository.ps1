# Compatible syntax: Windows PowerShell 5.1 and PowerShell 7.
[CmdletBinding()]
param([switch]$Publish, [switch]$Reviewed, [switch]$Public,
      [string]$Owner = 'jdmc-services', [string]$Name = 'enterprise-voice-migration-readiness',
      [switch]$LoadOnly)
$ErrorActionPreference = 'Stop'
function Invoke-NativeTool {
    param([string]$Tool, [string[]]$Arguments)
    if (-not (Get-Command $Tool -CommandType Application -ErrorAction SilentlyContinue)) {
        throw "Missing $Tool. Install it using START-PUBLISH.md, reopen PowerShell, then rerun."
    }
    $prior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $Tool @Arguments 2>&1 | ForEach-Object { [string]$_ })
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prior }
    return [pscustomobject]@{ ExitCode = $code; Output = ($output -join "`n") }
}
function Invoke-Publication {
    [CmdletBinding()]
    param([string]$Root, [switch]$Publish, [switch]$Reviewed, [switch]$Public,
          [string]$Owner = 'jdmc-services', [string]$Name = 'enterprise-voice-migration-readiness',
          [scriptblock]$Runner = { param($tool,$arguments) Invoke-NativeTool $tool $arguments })
    function Call-Tool([string]$Tool, [string[]]$Arguments) {
        $result = & $Runner $Tool $Arguments
        if ($null -eq $result -or $null -eq $result.ExitCode) { throw "No usable result from $Tool. Nothing further was attempted." }
        return $result
    }
    function Checked([string]$Tool, [string[]]$Arguments, [string]$Context) {
        $result = Call-Tool $Tool $Arguments
        if ($result.ExitCode -ne 0) { throw "$Context failed ($Tool exit $($result.ExitCode)). Check connectivity, authorization and local installation. Fix the cause and rerun the same command; no force-push is used. Native output is withheld to avoid revealing credentials." }
        return [string]$result.Output
    }
    function Parse-Object([string]$Text, [string]$Context) {
        if ([string]::IsNullOrWhiteSpace($Text)) { throw "Empty $Context response. Check connectivity/authentication and rerun; an empty response is not proof of absence." }
        try { $obj = ConvertFrom-Json -InputObject $Text -ErrorAction Stop } catch { throw "Invalid $Context response. Stop and check GitHub CLI connectivity before rerunning." }
        if ($null -eq $obj -or $obj -is [array] -or $obj -is [string] -or $obj -is [ValueType]) { throw "Unexpected $Context response. Expected one JSON object, not null or an array." }
        return $obj
    }
    function Read-RemoteRepository {
        $result = Call-Tool 'gh' @('api',"repos/$Owner/$Name",'--jq','{id,full_name,private}')
        if ($result.ExitCode -ne 0) {
            if ($result.Output -match '(?i)HTTP\s+404') { return $null }
            throw 'Repository lookup failed without a confirmed HTTP 404. Check GitHub connectivity/permissions and rerun. No repository creation was attempted.'
        }
        $repo = Parse-Object $result.Output 'repository API'
        if ($null -eq $repo.id -or [long]$repo.id -le 0 -or $repo.full_name -cne "$Owner/$Name" -or $repo.private -isnot [bool]) { throw 'Repository API identity or visibility is incomplete/unexpected. Stop and investigate.' }
        return $repo
    }
    function Save-State($State) {
        $json = $State | ConvertTo-Json -Depth 5
        $temporary = $statePath + '.tmp'
        [IO.File]::WriteAllText($temporary, $json, (New-Object Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $temporary -Destination $statePath -Force
    }
    if ($Owner -notmatch '^[A-Za-z0-9][A-Za-z0-9-]{0,38}$' -or $Name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$') { throw 'Use a valid personal GitHub account and repository name.' }
    $Root = [IO.Path]::GetFullPath($Root)
    & (Join-Path $Root 'scripts/validate-repository.ps1') -Root $Root
    $manifestPath = Join-Path $Root 'repository-manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $paths = @($manifest.files | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_.path }) + @('repository-manifest.json')
    $visibility = 'private'; if ($Public) { $visibility = 'public' }
    Write-Host "Upload preview: $Owner/$Name ($visibility)"
    foreach ($path in $paths) { Write-Host ('  {0} ({1} bytes)' -f $path, (Get-Item -LiteralPath (Join-Path $Root $path) -Force).Length) }
    Write-Host 'Scan covers selected credential/number patterns and unexpected files. Review all content; it cannot prove confidentiality.'
    if (-not $Publish) { Write-Host 'PREVIEW ONLY: no GitHub calls or local Git changes. Add -Publish -Reviewed after reviewing. Private is the default; public requires -Public.'; return }
    if (-not $Reviewed) { throw 'Review the preview and documents first. Then rerun with -Publish -Reviewed; use -Public only if you intend public visibility.' }
    $null = Checked 'git' @('--version') 'Git availability check'
    $null = Checked 'gh' @('--version') 'GitHub CLI availability check'
    $null = Checked 'gh' @('auth','status','--hostname','github.com') 'GitHub authentication check (use gh auth login --hostname github.com)'
    $user = Parse-Object (Checked 'gh' @('api','user','--jq','{login,id}') 'Account lookup') 'account API'
    if ($user.login -cne $Owner -or $null -eq $user.id -or [long]$user.id -le 0) { throw "Wrong or incomplete GitHub account. Expected $Owner. Run gh auth switch --hostname github.com --user $Owner (or gh auth login), then rerun." }
    Write-Host "Verified signed-in account: $Owner"
    $parent = Split-Path -Parent $Root
    $statePath = Join-Path $parent ".$Owner.$Name.publish-state.json"
    $work = Join-Path $parent "publish-work-$Owner-$Name"
    $hash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $url = "https://github.com/$Owner/$Name.git"
    $state = $null
    if (Test-Path -LiteralPath $statePath) {
        $state = Parse-Object (Get-Content -LiteralPath $statePath -Raw) 'local state'
        if ($state.schema -ne 1 -or $state.owner -cne $Owner -or $state.name -cne $Name -or $state.manifestHash -ne $hash -or $state.work -ne $work -or $state.visibility -ne $visibility -or $state.phase -notin @('prepared','created','complete') -or $state.commit -notmatch '^[a-f0-9]{40,64}$') { throw "Local publication state does not match this package or options. Stop; inspect $statePath and START-PUBLISH.md. Do not delete state to bypass safety." }
    }
    $repo = Read-RemoteRepository
    if ($null -ne $repo) {
        if ($null -eq $state -or $null -eq $state.repoId -or [long]$state.repoId -ne [long]$repo.id -or $state.phase -eq 'prepared') { throw "Repository $Owner/$Name already exists without matching creation state. STOP: it will not be overwritten or force-pushed. Choose a new -Name or inspect the existing repository manually." }
        if (($visibility -eq 'private') -ne $repo.private) { throw 'Existing repository visibility differs from the recorded choice. Stop; this script never changes visibility.' }
    } elseif ($null -ne $state -and $state.phase -ne 'prepared') { throw 'The previously created repository is no longer visible. Stop and verify access/deletion manually; it will not be recreated automatically.' }
    if ($null -eq $state) {
        if (Test-Path -LiteralPath $work) { throw "Local work folder already exists without state: $work. Inspect it; nothing will be overwritten." }
        $null = New-Item -ItemType Directory -Path $work
        foreach ($path in $paths) {
            $destination = Join-Path $work $path
            $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
            Copy-Item -LiteralPath (Join-Path $Root $path) -Destination $destination -Force
        }
        & (Join-Path $Root 'scripts/validate-repository.ps1') -Root $work
        $null = Checked 'git' @('-C',$work,'init') 'Local Git initialization'
        $null = Checked 'git' @('-C',$work,'symbolic-ref','HEAD','refs/heads/main') 'Main branch selection'
        $null = Checked 'git' @('-C',$work,'config','core.autocrlf','false') 'Local line-ending configuration'
        $null = Checked 'git' @('-C',$work,'config','user.name',$Owner) 'Local commit identity'
        $null = Checked 'git' @('-C',$work,'config','user.email',"$($user.id)+$Owner@users.noreply.github.com") 'Private commit email configuration'
        $null = Checked 'git' @('-C',$work,'add','--all') 'Staging reviewed package'
        $null = Checked 'git' @('-C',$work,'commit','-m','Add synthetic enterprise voice migration readiness portfolio') 'Initial commit'
        $tracked = @((Checked 'git' @('-C',$work,'ls-files') 'Committed file list verification') -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if (@(Compare-Object ($paths | Sort-Object) ($tracked | Sort-Object)).Count -ne 0) { throw 'Git did not include exactly the reviewed file list. Check local/global ignore rules before retrying. No repository was created.' }
        $commit = (Checked 'git' @('-C',$work,'rev-parse','HEAD') 'Local commit lookup').Trim()
        if ($commit -notmatch '^[a-f0-9]{40,64}$') { throw 'Local commit lookup was empty/invalid. No repository was created. Inspect the work folder before retrying.' }
        $null = Checked 'git' @('-C',$work,'remote','add','origin',$url) 'Remote configuration'
        $state = [pscustomobject]@{ schema=1; owner=$Owner; name=$Name; manifestHash=$hash; work=$work; visibility=$visibility; phase='prepared'; repoId=$null; commit=$commit }
        Save-State $state
    } else {
        if (-not (Test-Path -LiteralPath $work -PathType Container)) { throw 'Recorded local work folder is missing. Restore it before resuming; do not bypass state.' }
        if ((Checked 'git' @('-C',$work,'rev-parse','HEAD') 'Resume commit verification').Trim() -ne $state.commit -or (Checked 'git' @('-C',$work,'remote','get-url','origin') 'Resume remote verification').Trim() -ne $url) { throw 'Local commit/remote differs from recorded state. Stop and inspect; no push was attempted.' }
        if (-not [string]::IsNullOrWhiteSpace((Checked 'git' @('-C',$work,'status','--porcelain') 'Resume working-tree check'))) { throw 'Local publication work tree has changes. Stop; no push was attempted.' }
    }
    if ($null -eq $repo) {
        $flag = '--private'; if ($Public) { $flag = '--public' }
        $null = Checked 'gh' @('repo','create',"$Owner/$Name",$flag,'--description','Synthetic enterprise voice migration readiness portfolio') 'Repository creation'
        $repo = Read-RemoteRepository
        if ($null -eq $repo) { throw 'Creation returned but repository identity could not be verified. Stop and inspect GitHub; rerun will refuse an unrecorded existing repository.' }
        if (($visibility -eq 'private') -ne $repo.private) { throw 'Created visibility is unexpected. Stop and inspect GitHub; no push was attempted.' }
        $state.repoId = [long]$repo.id; $state.phase = 'created'; Save-State $state
    }
    $refsText = Checked 'git' @('-C',$work,'ls-remote','--heads','--tags',$url) 'Remote branch/tag lookup'
    $refs = @($refsText -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($refs.Count -gt 0) {
        if ($refs.Count -eq 1 -and $refs[0] -match '^([a-f0-9]{40,64})\s+refs/heads/main$' -and $Matches[1] -eq $state.commit) {
            $state.phase = 'complete'; Save-State $state
            Write-Host "ALREADY COMPLETE: https://github.com/$Owner/$Name. No write performed."; return
        }
        throw 'The recorded repository contains unexpected commits, branches or tags. STOP: no overwrite or force-push is allowed.'
    }
    if ($state.phase -eq 'complete') { throw 'Completed publication now has an empty remote. Stop and investigate; no automatic re-push.' }
    $null = Checked 'gh' @('auth','setup-git','--hostname','github.com') 'GitHub HTTPS authentication setup'
    $null = Checked 'git' @('-C',$work,'push','--set-upstream','origin','main:main') 'Push (if interrupted, rerun this same command with the same options and state file)'
    $verify = (Checked 'git' @('-C',$work,'ls-remote','--heads','--tags',$url) 'Post-push verification').Trim()
    if ($verify -notmatch '^([a-f0-9]{40,64})\s+refs/heads/main$' -or $Matches[1] -ne $state.commit) { throw 'Push could not be verified. Keep the state and work folder, then rerun; do not force-push.' }
    $state.phase = 'complete'; Save-State $state
    Write-Host "PUBLISHED ($visibility): https://github.com/$Owner/$Name"
}
if (-not $LoadOnly) {
    try { Invoke-Publication -Root $PSScriptRoot -Publish:$Publish -Reviewed:$Reviewed -Public:$Public -Owner $Owner -Name $Name }
    catch { Write-Error -Message $_.Exception.Message -ErrorAction Continue; exit 1 }
}
