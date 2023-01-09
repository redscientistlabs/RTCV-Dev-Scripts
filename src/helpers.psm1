using namespace System.Management.Automation.Host

$ValidRepos = @{
    "BizHawk-Vanguard"      = "master";
    "dolphin-Vanguard"      = "Vanguard";
    "FileStubTemplate-Cemu" = "main";
    "FileStub-Vanguard"     = "master";
    "melonDS-Vanguard"      = "Vanguard";
    "pcsx2-Vanguard"        = "Vanguard";
    "ProcessStub-Vanguard"  = "master";
    "RTCV"                  = "51X";
    "xemu-Vanguard"         = "master";
}

function Remove-InvalidRepos([System.Collections.ArrayList]$repos) {
    for ($i = 0; $i -lt $repos.Count; $i++) {
        $repo = $repos[$i]
        if (-not $ValidRepos.Contains($repo)) {
            Write-Host "Invalid repo: '$repo'. Skipping..." -ForegroundColor Yellow
            $repos.Remove($repo)
        }
    }
}

function Get-AllRepos() {
    return $ValidRepos.Keys
}

function Clone-Repo([string]$repo, [string]$directory, [bool]$silent) {
    $repoBaseUrl = 'git@github.com:redscientistlabs/';
    $repoUrl = $repoBaseUrl + $repo + '.git';
    $repoDirectory = $directory + '\' + $repo;
    $branch = $ValidRepos[$repo];
    if (Test-Path $repoDirectory) {
        Write-Host "Repo '$repo' already exists locally." -ForegroundColor Yellow
        if ($silent) {
            Write-Host "Skipping..." -ForegroundColor Yellow
            return
        }

        $answer = $Host.UI.PromptForChoice("$repo - Checkout branch '$branch' ?", "This may override local changes", @('&Yes', '&No'), 1)
        if ($answer -ne 0) {
            Write-Host "Skipping..." -ForegroundColor Blue
            return
        }
    }
    else {
        Write-Host "Cloning '$repo' into $repoDirectory" -ForegroundColor Blue
        git clone $repoUrl $repoDirectory
    }

    Write-Host "Checking out '$($branch)'..." -ForegroundColor Blue
    git -C $repoDirectory checkout $branch
}
