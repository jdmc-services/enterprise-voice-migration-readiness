# Publish from Windows with minimal input

Preparation has not created or published a GitHub repository. Read [README.md](README.md) and review the files first. Publication is private by default. A public repository is visible to anyone and does not, by itself, verify professional experience.

## 1. Extract and open PowerShell in the right folder

Download the ZIP and use **Extract All** in File Explorer. Open the extracted `enterprise-voice-migration-readiness` folder containing this guide and `publish-repository.ps1`. Click File Explorer's address bar, type `powershell`, and press Enter. This opens Windows PowerShell in that folder; you can use `pwsh` instead if installed.

Confirm the location:

```powershell
Get-Location
Test-Path .\publish-repository.ps1
```

The second command must return `True`. Do not run from System32. You can extract to Downloads; OneDrive is not required. Close any editor changing these files while publishing.

If downloaded scripts are blocked on a personal computer, unblock only this package's scripts and use a policy scoped to the current session:

```powershell
Get-ChildItem -LiteralPath . -Recurse -Filter *.ps1 | Unblock-File
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
```

This process setting ends when this PowerShell window closes. Organization Group Policy may override it; use an approved environment rather than bypassing organization controls.

## 2. Preview and check tools

```powershell
.\publish-repository.ps1
git --version
gh --version
```

The first command validates the package, scans selected sensitive patterns, and lists every upload file and size. It makes no GitHub calls and no local Git changes. Read the preview and documents; automated checks cannot recognize every confidential detail.

If Git or GitHub CLI is missing, use these commands if Windows Package Manager is available, then close and reopen PowerShell in this folder:

```powershell
winget install --id Git.Git -e
winget install --id GitHub.cli -e
```

If `winget` is unavailable, use the official installers at [Git for Windows](https://git-scm.com/download/win) and [GitHub CLI](https://cli.github.com/). No installation is required to read the documents.

## 3. Confirm your GitHub account

```powershell
gh auth status --hostname github.com
gh api user --jq .login
```

The account must be `jdmc-services`. If already correct, continue. Otherwise:

```powershell
gh auth login --hostname github.com --git-protocol https --web
```

Choose your `jdmc-services` account in the browser. If another saved account is active:

```powershell
gh auth switch --hostname github.com --user jdmc-services
```

The publisher checks the active API identity again and stops on a wrong account, missing tools, failed authentication, empty or invalid responses, unreviewed content, or changed package files. It uses your GitHub numeric ID and account name for the commit's GitHub no-reply email rather than your local personal email. `gh auth setup-git` configures local GitHub HTTPS authentication for publishing.

## 4. Publish once — choose one command

**Private, the default:**

```powershell
.\publish-repository.ps1 -Publish -Reviewed
```

**Public, only after reviewing for public release:**

```powershell
.\publish-repository.ps1 -Publish -Reviewed -Public
```

`-Reviewed` records your affirmative content review; it is not a confidentiality certificate. `-Public` explicitly authorizes public creation. This script never changes visibility of an existing repository. It creates only `jdmc-services/enterprise-voice-migration-readiness`, without altering your two existing repositories. It prints the repository URL when complete.

For a different intended personal account, explicitly pass `-Owner YOUR-ACCOUNT` in preview and publication. For a different new repository name, pass `-Name NEW-NAME` in both commands. You must be signed into that exact owner account; organization publishing is not supported by this handoff.

## If an error occurs: resume safely

Read the error, fix its cause, and rerun the **same publication command with the same visibility and name**. Keep the extracted package, the adjacent `publish-work-jdmc-services-enterprise-voice-migration-readiness` folder, and the adjacent `.jdmc-services.enterprise-voice-migration-readiness.publish-state.json` file together. These local state/work files are outside the upload and are not included in the ZIP.

| Situation | What happens / next step |
| --- | --- |
| Failed before a local commit/state was saved | No remote creation was attempted. An incomplete work folder causes a safe stop. Preserve it for inspection; move it aside only after verifying no repository was created, then retry from a fresh extraction. |
| Creation failed with a saved prepared state | Rerun; creation is retried only if GitHub confirms HTTP 404. A network or authorization error is not treated as absence. |
| Creation succeeded but identity/state could not be confirmed | Stop and inspect GitHub. Rerun refuses an existing repository without recorded matching ID. Do not delete it or bypass the check; choose a new unused name for a separate reviewed attempt if needed. |
| Push interrupted after recorded creation | Rerun resumes only the same repository ID, package, options, local commit and empty remote. A remote main already equal to the recorded commit is reported complete without another push. |
| An existing repository predates this package | Stop; nothing is overwritten. Choose a new unused `-Name` or review that repository manually. |
| Remote contains unexpected commits, branches or tags | Stop. No overwrite, force-push or automatic merge is performed. |
| Package changed or has extra files | Restore the clean ZIP, or intentionally review edits and run `.\scripts\update-manifest.ps1` before starting a fresh publication attempt. Do not regenerate a manifest merely to suppress a warning. |
| Repository disappears, visibility changes, or recorded state differs | Stop and investigate access/state manually. No automatic recreation or visibility change. |

Do not edit or delete the state file to force a retry. If publication is ambiguous, inspect the GitHub repository in the browser before any new action. Once complete, read README and START-HERE on GitHub; for a public repository, open its URL in an incognito window. Add a profile link only when you are satisfied with the presentation. No profile modification is included here.

## Local verification commands

```powershell
.\scripts\validate-repository.ps1
.\tests\test-publishing.ps1
```

Tests run in temporary folders with all GitHub calls and remote Git writes mocked. One test uses real local Git for initialization, staging and committing. None creates a remote repository. See [VALIDATION.md](VALIDATION.md) for actual environment coverage and known limits.
