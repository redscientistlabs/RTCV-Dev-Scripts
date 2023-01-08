<#
.SYNOPSIS
    Setup script for RTCV

.DESCRIPTION
    Run this script whenever you want to add repos to your RTCV setup. Example:

    .\setup.ps1 -repos RTCV,dolphin-vanguard -directory C:\Code
#>
[CmdletBinding()]
param (
    [Parameter(HelpMessage = "Not interactive, install based on input flags")]
    [switch]$silent = $false,

    [Parameter(HelpMessage = "Directory to clone repos to")]
    [string]$directory = (Split-Path $PSScriptRoot -Parent),

    [Parameter(HelpMessage = "Repos to clone")]
    [System.Collections.ArrayList]$repos = @("RTCV"),

    # TODO - Building on clone may be nice for some devs.
    # [Parameter(HelpMessage = "Run a restore and build upon cloning")]
    # [switch]$build = $false,

    # Swallow all remaining arguments. This avoid things like:
    #  .\setup.ps1 -repos RTCV dolphin-vanguard
    # From assigning "dolphin-vanguard" to the "directory" parameter. Powershell 😡
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)] $extraArgs
)

Write-Host "Writing to:`t$directory" -ForegroundColor Blue

# PowerShell will use a stale version of the module by default. This makes development very tedious.
# Without `-Force`, you need to reload your whole dev environment every time you want to make a change
# to a module. It's insane that this is a real issue a language has in 2023. 😡
# See https://github.com/PowerShell/PowerShell/issues/2505
Import-Module ".\src\helpers.psm1" -Force

Remove-InvalidRepos($repos)
Write-Host "Cloning repos:`t$($repos -Join ', ')" -ForegroundColor Blue

if ($silent) {
    # By default, checkout RTCV
}

echo $repos
echo $repos.Count
