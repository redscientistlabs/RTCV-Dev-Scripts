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

function Clone-Repo([string]$repo, [string]$directory) {
    $repoBaseUrl = 'git@github.com:redscientistlabs/';
    $repoUrl = $repoBaseUrl + $repo + '.git';
    $repoDirectory = $directory + '\' + $repo;
    if (Test-Path $repoDirectory) {
        Write-Host "Repo '$repo' already exists. Skipping..." -ForegroundColor Yellow
        return
    }
    Write-Host "Cloning '$repo'..." -ForegroundColor Green
    git clone $repoUrl $repoDirectory
    Write-Host "Checking out '$($ValidRepos[$repo])'..." -ForegroundColor Green
    git -C $repoDirectory checkout $ValidRepos[$repo]
}
