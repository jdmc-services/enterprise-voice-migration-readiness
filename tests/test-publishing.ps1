[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$package = Split-Path -Parent $PSScriptRoot
. (Join-Path $package 'publish-repository.ps1') -LoadOnly
$script:passed = 0
$script:testBase = Join-Path ([IO.Path]::GetTempPath()) ('voice-publisher-tests-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $script:testBase
function Assert-Test($Condition,[string]$Message) { if (-not $Condition) { throw "TEST FAILURE: $Message" } }
function New-Fixture {
    $parent = Join-Path $script:testBase ([guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $parent
    $root = Join-Path $parent 'package'
    Copy-Item -LiteralPath $package -Destination $root -Recurse -Force
    $script:fake = @{ Calls = (New-Object Collections.ArrayList); Exists=$false; Public=$false; Remote=''; Commit=('a' * 40); Account='normal'; Lookup='normal'; AuthFail=$false; MissingGit=$false; MissingGh=$false; PushFails=0; CreateFails=0; PostCreateEmpty=$false; LostAck=$false; RealGit=$false }
    return $root
}
$script:runner = {
    param($tool,$arguments)
    $null = $script:fake.Calls.Add([pscustomobject]@{ Tool=$tool; Arguments=@($arguments) })
    $code=0; $output=''
    if ($tool -eq 'gh') {
        if ($arguments[0] -eq '--version') { if ($script:fake.MissingGh) { $code=127 } else { $output='gh test-double' } }
        elseif ($arguments[0] -eq 'auth') { if ($arguments[1] -eq 'status' -and $script:fake.AuthFail) { $code=1 } }
        elseif ($arguments[0] -eq 'api' -and $arguments[1] -eq 'user') {
            switch ($script:fake.Account) {
                'empty' { $output='' }
                'null' { $output='null' }
                'array' { $output='[]' }
                'malformed' { $output='{' }
                'wrong' { $output='{"login":"other-user","id":123}' }
                'missing-id' { $output='{"login":"jdmc-services"}' }
                default { $output='{"login":"jdmc-services","id":123}' }
            }
        }
        elseif ($arguments[0] -eq 'api') {
            if ($script:fake.PostCreateEmpty -and $script:fake.Exists) { $output='' }
            elseif ($script:fake.Lookup -eq 'network') { $code=1; $output='connection failed' }
            elseif ($script:fake.Lookup -eq 'empty') { $output='' }
            elseif ($script:fake.Lookup -eq 'null') { $output='null' }
            elseif ($script:fake.Lookup -eq 'array') { $output='[]' }
            elseif ($script:fake.Lookup -eq 'malformed') { $output='{' }
            elseif ($script:fake.Lookup -eq 'identity') { $output='{"id":999,"full_name":"other/repo","private":true}' }
            elseif ($script:fake.Exists) { $output = @{ id=999; full_name='jdmc-services/enterprise-voice-migration-readiness'; private=(-not $script:fake.Public) } | ConvertTo-Json -Compress }
            else { $code=1; $output='Not Found (HTTP 404)' }
        }
        elseif ($arguments[0] -eq 'repo' -and $arguments[1] -eq 'create') {
            if ($script:fake.CreateFails -gt 0) { $script:fake.CreateFails--; $code=1 }
            else { $script:fake.Exists=$true; $script:fake.Public=($arguments -contains '--public'); $output='https://github.com/jdmc-services/enterprise-voice-migration-readiness' }
        }
        else { throw "Unexpected mocked gh command: $arguments" }
    } elseif ($tool -eq 'git') {
        if ($arguments[0] -eq '--version') { if ($script:fake.MissingGit) { $code=127 } else { $output='git test-double' } }
        else {
            $action = $arguments[2]
            switch ($action) {
                'ls-remote' { $output=$script:fake.Remote }
                'push' {
                    if ($script:fake.PushFails -gt 0) { $script:fake.PushFails--; $code=1 }
                    else { $script:fake.Remote=$script:fake.Commit + "`trefs/heads/main"; if ($script:fake.LostAck) { $code=1; $script:fake.LostAck=$false } }
                }
                default {
                    if ($script:fake.RealGit) {
                        $actual = Invoke-NativeTool $tool $arguments
                        if ($action -eq 'rev-parse' -and $actual.ExitCode -eq 0) { $script:fake.Commit=$actual.Output.Trim() }
                        return $actual
                    }
                    if ($action -eq 'ls-files') { $m=Get-Content -LiteralPath (Join-Path $arguments[1] 'repository-manifest.json') -Raw | ConvertFrom-Json; $output=(@($m.files.path)+@('repository-manifest.json')) -join "`n" }
                    elseif ($action -eq 'rev-parse') { $output=$script:fake.Commit }
                    elseif ($action -eq 'remote' -and $arguments[3] -eq 'get-url') { $output='https://github.com/jdmc-services/enterprise-voice-migration-readiness.git' }
                    elseif ($action -notin @('init','symbolic-ref','config','add','commit','remote','status')) { throw "Unexpected mocked git command: $arguments" }
                }
            }
        }
    } else { throw "Unexpected tool: $tool" }
    return [pscustomobject]@{ ExitCode=$code; Output=$output }
}
function Run-Publish([string]$Root,[switch]$Public) { Invoke-Publication -Root $Root -Publish -Reviewed -Public:$Public -Runner $script:runner 6>$null }
function Expect-Failure([scriptblock]$Action,[string]$Pattern) {
    $message=''
    try { & $Action } catch { $message=$_.Exception.Message }
    Assert-Test ($message -match $Pattern) "Expected failure /$Pattern/, got '$message'"
}
function Count-Create { return @($script:fake.Calls | Where-Object { $_.Tool -eq 'gh' -and $_.Arguments[0] -eq 'repo' -and $_.Arguments[1] -eq 'create' }).Count }
function Count-Push { return @($script:fake.Calls | Where-Object { $_.Tool -eq 'git' -and $_.Arguments -contains 'push' }).Count }
function Test-Case([string]$Name,[scriptblock]$Body) {
    & $Body
    $script:passed++
    Write-Host "PASS $Name"
}
try {
    Test-Case 'preview is mutation-free and offline' {
        $r=New-Fixture; Invoke-Publication -Root $r -Runner $script:runner 6>$null
        Assert-Test ($script:fake.Calls.Count -eq 0) 'Preview called a tool.'
    }
    Test-Case 'publication requires explicit review' {
        $r=New-Fixture; Expect-Failure { Invoke-Publication -Root $r -Publish -Runner $script:runner 6>$null } 'Review the preview'
        Assert-Test ($script:fake.Calls.Count -eq 0) 'Unreviewed publication called a tool.'
    }
    Test-Case 'missing Git and failed authentication stop' {
        $r=New-Fixture; $script:fake.MissingGit=$true; Expect-Failure { Run-Publish $r } 'Git availability'
        $r=New-Fixture; $script:fake.MissingGh=$true; Expect-Failure { Run-Publish $r } 'GitHub CLI availability'
        $r=New-Fixture; $script:fake.AuthFail=$true; Expect-Failure { Run-Publish $r } 'authentication check'
        Assert-Test ((Count-Create) -eq 0) 'Created after authentication failure.'
    }
    foreach ($kind in @('empty','null','array','malformed','wrong','missing-id')) {
        Test-Case "account response $kind stops" {
            $r=New-Fixture; $script:fake.Account=$kind; Expect-Failure { Run-Publish $r } 'account|Account'
            Assert-Test ((Count-Create) -eq 0 -and (Count-Push) -eq 0) 'Account failure wrote remotely.'
        }
    }
    foreach ($kind in @('empty','null','array','malformed','network','identity')) {
        Test-Case "repository response $kind stops" {
            $r=New-Fixture; $script:fake.Lookup=$kind; Expect-Failure { Run-Publish $r } 'repository|Repository'
            Assert-Test ((Count-Create) -eq 0) 'Bad lookup caused creation.'
        }
    }
    Test-Case 'preexisting repository never overwritten' {
        $r=New-Fixture; $script:fake.Exists=$true; Expect-Failure { Run-Publish $r } 'already exists'
        Assert-Test ((Count-Create) -eq 0 -and (Count-Push) -eq 0) 'Existing repo mutated.'
    }
    Test-Case 'private default and completed rerun' {
        $r=New-Fixture; Run-Publish $r; Run-Publish $r
        Assert-Test (-not $script:fake.Public -and (Count-Create) -eq 1 -and (Count-Push) -eq 1) 'Private default or idempotent rerun failed.'
        Assert-Test (@($script:fake.Calls | Where-Object { $_.Arguments -contains '--force' -or $_.Arguments -contains '--force-with-lease' }).Count -eq 0) 'Force flag used.'
    }
    Test-Case 'explicit public option and recorded option match' {
        $r=New-Fixture; Run-Publish $r -Public; Assert-Test $script:fake.Public 'Explicit public not used.'
        Expect-Failure { Run-Publish $r } 'state does not match'
        Run-Publish $r -Public; Assert-Test ((Count-Create) -eq 1 -and (Count-Push) -eq 1) 'Public rerun wrote again.'
    }
    Test-Case 'interrupted push resumes once' {
        $r=New-Fixture; $script:fake.PushFails=1; Expect-Failure { Run-Publish $r } 'Push.*failed'
        Run-Publish $r; Run-Publish $r
        Assert-Test ((Count-Create) -eq 1 -and (Count-Push) -eq 2) 'Push retry duplicated creation or push.'
    }
    Test-Case 'lost push acknowledgement detected on rerun' {
        $r=New-Fixture; $script:fake.LostAck=$true; Expect-Failure { Run-Publish $r } 'Push.*failed'
        Run-Publish $r; Assert-Test ((Count-Push) -eq 1) 'Already accepted push repeated.'
    }
    Test-Case 'failed creation resumes prepared state' {
        $r=New-Fixture; $script:fake.CreateFails=1; Expect-Failure { Run-Publish $r } 'creation failed'
        Run-Publish $r; Assert-Test ((Count-Create) -eq 2 -and (Count-Push) -eq 1) 'Prepared retry failed.'
    }
    Test-Case 'ambiguous successful creation stops on rerun' {
        $r=New-Fixture; $script:fake.PostCreateEmpty=$true; Expect-Failure { Run-Publish $r } 'Empty repository'
        $script:fake.PostCreateEmpty=$false; Expect-Failure { Run-Publish $r } 'already exists'
        Assert-Test ((Count-Create) -eq 1 -and (Count-Push) -eq 0) 'Ambiguous creation was bypassed.'
    }
    Test-Case 'unexpected remote refs prevent push' {
        $r=New-Fixture; $script:fake.Remote=('b'*40) + "`trefs/heads/main"; Expect-Failure { Run-Publish $r } 'unexpected commits'
        Assert-Test ((Count-Push) -eq 0) 'Unexpected main overwritten.'
    }
    Test-Case 'deleted or changed visibility repository stops' {
        $r=New-Fixture; Run-Publish $r; $script:fake.Exists=$false; Expect-Failure { Run-Publish $r } 'no longer visible'
        $script:fake.Exists=$true; $script:fake.Public=$true; Expect-Failure { Run-Publish $r } 'visibility differs'
        Assert-Test ((Count-Create) -eq 1 -and (Count-Push) -eq 1) 'State mismatch mutated remote.'
    }
    Test-Case 'extra file and changed package blocked' {
        $r=New-Fixture; Set-Content -LiteralPath (Join-Path $r 'extra.md') -Value 'unexpected'
        Expect-Failure { Run-Publish $r } 'Unlisted file'
        $r=New-Fixture; Add-Content -LiteralPath (Join-Path $r 'README.md') -Value 'changed'
        Expect-Failure { Run-Publish $r } 'Package file changed'
        Assert-Test ($script:fake.Calls.Count -eq 0) 'Changed package called a tool.'
    }
    Test-Case 'negative semantic and privacy validation' {
        $r=New-Fixture
        $inventory=Join-Path $r 'data/inventory.csv'
        $text=Get-Content -LiteralPath $inventory -Raw
        [IO.File]::WriteAllText($inventory,$text.Replace('800,100,50,50,1000','799,100,50,50,1000'))
        Expect-Failure { & (Join-Path $r 'scripts/validate-repository.ps1') -Root $r -SkipManifest 6>$null } 'Inventory range/count'
        $r=New-Fixture; Add-Content -LiteralPath (Join-Path $r 'README.md') -Value ('gh'+'p_'+('X'*36))
        Expect-Failure { & (Join-Path $r 'scripts/validate-repository.ps1') -Root $r -SkipManifest 6>$null } 'sensitive content'
        $r=New-Fixture; Add-Content -LiteralPath (Join-Path $r 'README.md') -Value '[broken](missing.md)'
        Expect-Failure { & (Join-Path $r 'scripts/validate-repository.ps1') -Root $r -SkipManifest 6>$null } 'Broken/unsupported local link'
    }
    Test-Case 'personal email findings are blocked without printing the value' {
        $r=New-Fixture; Add-Content -LiteralPath (Join-Path $r 'README.md') -Value ('person'+'@'+'example.invalid')
        Expect-Failure { & (Join-Path $r 'scripts/validate-repository.ps1') -Root $r -SkipManifest 6>$null } 'sensitive content'
    }
    Test-Case 'real local Git commit with all remote writes mocked' {
        $r=New-Fixture; $script:fake.RealGit=$true; Run-Publish $r; Run-Publish $r
        Assert-Test ((Count-Create) -eq 1 -and (Count-Push) -eq 1 -and $script:fake.Commit -ne ('a'*40)) 'Real Git test did not commit or rerun safely.'
    }
    Write-Host "RESULT: $script:passed test groups passed. GitHub and remote writes mocked; no publication."
} finally {
    Remove-Item -LiteralPath $script:testBase -Recurse -Force
}
