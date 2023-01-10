using namespace System.Management.Automation.Host

[CmdletBinding()]
param (
    [Parameter(HelpMessage = "Not interactive, install based on input flags")]
    [switch]$silent = $false,

    [Parameter(HelpMessage = "Directory to clone repos to")]
    [string]$directory = (Split-Path $PSScriptRoot -Parent),

    [Parameter(HelpMessage = "Repos to clone")]
    [string[]]$repos = @("RTCV", "BizHawk-Vanguard"),

    [Parameter(HelpMessage = "Clone all of the repos")]
    [switch]$all = $false,

    # TODO - Building on clone may be nice for some devs.
    # [Parameter(HelpMessage = "Run a restore and build upon cloning")]
    # [switch]$build = $false,

    # Swallow all remaining arguments. This avoid things like:
    #  .\setup.ps1 -repos RTCV dolphin-vanguard
    # From assigning "dolphin-vanguard" to the "directory" parameter. Powershell 😡
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)] $extraArgs
)

function Main () {
    Write-Host "Writing to:`t$directory" -ForegroundColor Blue

    if ($all) {
        $repos = Get-AllRepos
    }
    else {
        Remove-InvalidRepos($repos)
    }

    Write-Host "Cloning repos:`t$($repos -Join ', ')" -ForegroundColor Blue
    foreach ($repo in $repos) {
        Clone-Repo $repo $directory $silent;
    }

    Write-Host "Done!" -ForegroundColor Green
}

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

        $answer = $Host.UI.PromptForChoice("Checkout branch '$branch' in repo '$repo'?", "This may override local changes", @('&Yes', '&No'), 1)
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
    git pull
}

Main
