$ValidRepos = @(
    "BizHawk-Vanguard",
    "dolphin-vanguard",
    "FileStubTemplate-Cemu",
    "FileStub-Vanguard",
    "melonDS-Vanguard"
    "pcsx2-Vanguard",
    "ProcessStub-Vanguard",
    "RTCV",
    "xemu-Vanguard"
)

function Remove-InvalidRepos([System.Collections.ArrayList]$repos) {
    for ($i = 0; $i -lt $repos.Count; $i++) {
        $repo = $repos[$i]
        if (-not $ValidRepos.Contains($repo)) {
            Write-Host "Invalid repo: $repo" -ForegroundColor Red
            $repos.Remove($repo)
        }
    }
}
