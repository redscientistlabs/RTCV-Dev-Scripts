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
    [string[]]$repos = @("RTCV"),

    [Parameter(HelpMessage = "Run a restore and build upon cloning")]
    [switch]$build = $false,

    # Swallow all remaining arguments. This avoid things like:
    #  .\setup.ps1 -repos RTCV dolphin-vanguard
    # From assigning "dolphin-vanguard" to the "directory" parameter. Powershell 😡
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)] $extraArgs
)


Write-Host "Writing to $directory" -ForegroundColor Blue

if ($silent) {
    # By default, checkout RTCV
}

echo $repos
echo $repos.Count
