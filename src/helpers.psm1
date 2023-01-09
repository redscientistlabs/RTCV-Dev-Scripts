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
