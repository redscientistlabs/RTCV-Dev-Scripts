<#
.SYNOPSIS
    RTCV Dev setup

.DESCRIPTION
    Set up a developer environment for RTCV.
#>

using namespace System.Management.Automation.Host

[CmdletBinding()]
param (
    # Not interactive, install based on input flags
    [switch]$silent = $false,

    # Directory to clone repos to
    [string]$directory = $(if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { $pwd }),

    # Repos to clone. Example: setup.ps1 -repos RTCV,BizHawk-Vanguard
    [string[]]$repos = @(),

    # Name of the mega-solution file to generate in the root folder
    [string]$solutionFileName = "RTCV-Suite.sln",

    # Clone all of the repos
    [switch]$all = $false,

    # Don't create a mega-solution file
    [switch]$noSolution = $false,

    # Clone with HTTPS instead of SSH
    [switch]$https = $false,

    # TODO - Building on clone may be nice for some devs.
    # [switch]$build = $false,

    # Swallow all remaining arguments. This avoids commands like:
    #  .\setup.ps1 -repos RTCV dolphin-vanguard
    # From assigning "dolphin-vanguard" to the "directory" parameter. Powershell 😡
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)] $extraArgs
)

function Main () {
    Test-Prerequisites

    Write-Host "Cloning projects to:`t$directory" -ForegroundColor Blue

    if ($all) {
        $repos = Get-AllRepos
    }
    elseif ($repos.Count -ne 0) {
        $repos = Remove-InvalidRepos($repos)
    }
    else {
        $repos = Prompt-UserForRepos
    }

    Write-Host "Cloning repos:`t`t$($repos -Join ', ')" -ForegroundColor Blue
    foreach ($repo in $repos) {
        Get-HorizontalLine
        Clone-Repo $repo $directory $silent;
    }
    Get-HorizontalLine

    if (-not $noSolution) {
        Merge-Solutions $directory $solutionFileName
        Get-HorizontalLine
    }
    Write-Host "Done!" -ForegroundColor Green
}

class Repo {
    [string]$Name
    [string]$Branch
    [string]$slnPath
}

$ValidRepos = @(
    [Repo]@{Name = "BizHawk-Vanguard"; Branch = "master"; slnPath = "BizHawk.sln" }
    [Repo]@{Name = "dolphin-Vanguard"; Branch = "Vanguard"; slnPath = "Source\dolphin-emu.sln" }
    [Repo]@{Name = "FileStubTemplate-Cemu"; Branch = "main"; slnPath = "Plugin.sln" }
    [Repo]@{Name = "FileStub-Vanguard"; Branch = "master"; slnPath = "FileStub-Vanguard.sln" }
    # melonDS doesn't have a solution file, must be generated using cmake
    # I would include instructions on how to generate the solution, but I can't build melonDS-Vanguard locally
    # For now, I'm putting in a bogus sln file so the rest of the script doesn't break.
    [Repo]@{Name = "melonDS-Vanguard"; Branch = "Vanguard"; slnPath = "TODO.sln" }
    [Repo]@{Name = "pcsx2-Vanguard"; Branch = "Vanguard"; slnPath = "PCSX2_suite.sln" }
    [Repo]@{Name = "ProcessStub-Vanguard"; Branch = "master"; slnPath = "ProcessStub-Vanguard.sln" }
    [Repo]@{Name = "RTCV"; Branch = "51X"; slnPath = "RTCV.sln" }
    # xemu is a prototype that needs more work and is dependent on RTCVDLLHOOK
    # [Repo]@{Name =  "xemu-Vanguard"; Branch = "master"; slnPath = "xemu-Vanguard.sln"
)

# TODO - In the future, we should be smart about merging the existing `nuget.config` files in each repo
$NugetConfigContent = @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
'@

function Merge-Solutions([string]$directory, [string]$solutionFileName) {
    # Download the executable for use
    # TODO - We should probably migrate `merge-solutions.exe` to the RedScientistLab org
    $mergeSolutionsUrl = 'https://github.com/scowalt/merge-solutions/releases/download/test-release3/merge-solutions.exe'
    $mergeSolutionsPath = "$env:TMP\merge-solutions.exe"
    if (-not (Test-Path $mergeSolutionsPath)) {
        Write-Host "Downloading merge-solutions.exe..." -ForegroundColor Blue
        Invoke-WebRequest -Uri $mergeSolutionsUrl -OutFile $mergeSolutionsPath
    }

    $solutionFiles = ($ValidRepos | ForEach-Object { Join-Path $directory "$($_.Name)\$($_.slnPath)" } | Where-Object { if (Test-Path $_) { return $true } else { Write-Host "Couldn't find $_" -ForegroundColor Yellow; return $false; } })

    Write-Host "Calling merge-solutions.exe" -ForegroundColor Blue
    Invoke-Expression "& '$mergeSolutionsPath' /out $(Join-Path $directory $solutionFileName) $([String]::Join(' ', $solutionFiles))"

    # Packages in the merged solution file may not restore correctly without a local `nuget.config` file
    $nugetConfigPath = Join-Path $directory "nuget.config"
    Write-Host "Writing nuget.config" -ForegroundColor Blue
    $NugetConfigContent | Out-File $nugetConfigPath -Encoding ASCII
}

function Test-Prerequisites {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git is not installed. Please install it and try again." -ForegroundColor Red
        exit 1
    }

    # Show notification to change execution policy
    $allowedExecutionPolicy = @('Unrestricted', 'RemoteSigned', 'ByPass')
    if ((Get-ExecutionPolicy).ToString() -notin $allowedExecutionPolicy) {
        Write-Host "PowerShell requires an execution policy in [$($allowedExecutionPolicy -join ", ")] to run this script. For example, to set the execution policy to 'RemoteSigned' please run 'Set-ExecutionPolicy RemoteSigned -Scope CurrentUser'."  -ForegroundColor Red
        exit 1
    }
}

function Remove-InvalidRepos([System.Collections.ArrayList]$repos) {
    $output = @()
    for ($i = 0; $i -lt $repos.Count; $i++) {
        $repo = $repos[$i]
        if (-not ($ValidRepos.Name -contains $repo)) {
            Write-Host "Invalid repo: '$repo'. Skipping..." -ForegroundColor Yellow
        }
        else {
            $output += $repo
        }
    }

    return $output
}

function Prompt-UserForRepos {
    $options = $ValidRepos.Name | ForEach-Object { $_ }
    Write-Host "Select repos to clone:" -ForegroundColor Blue
    Show-Menu $options -MultiSelect
    return @()
}

function Get-AllRepos() {
    return $ValidRepos.Name
}

function Clone-Repo([string]$repo, [string]$directory, [bool]$silent) {
    $repoBaseUrl = if ($https) { 'https://github.com/redscientistlabs/' } else { 'git@github.com:redscientistlabs/' };
    $repoUrl = $repoBaseUrl + $repo + '.git';
    $repoDirectory = $directory + '\' + $repo;
    $branch = ($ValidRepos | Where-Object -FilterScript { $_.Name -eq $repo }).Branch
    if (Test-Path $repoDirectory) {
        Write-Host "Repo '$repo' already exists locally at $repoDirectory." -ForegroundColor Yellow
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
        git clone --recursive $repoUrl $repoDirectory
    }

    Write-Host "Updating $repo to '$($branch)'..." -ForegroundColor Blue
    git -C $repoDirectory checkout $branch
    git -C $repoDirectory pull
}

### Code stolen from https://github.com/Sebazzz/PSMenu
# There's no great way for me to import this code, so I'm just copy/pasting it.

# Ref: https://docs.microsoft.com/en-us/windows/desktop/inputdev/virtual-key-codes
function Toggle-Selection {
    param ($Position, [Array]$CurrentSelection)
    if ($CurrentSelection -contains $Position) {
        $result = $CurrentSelection | where { $_ -ne $Position }
    }
    else {
        $CurrentSelection += $Position
        $result = $CurrentSelection
    }

    Return $Result
}

function Get-PositionWithVKey([Array]$MenuItems, [int]$Position, $VKeyCode) {
    $MinPosition = 0
    $MaxPosition = $MenuItems.Count - 1
    $WindowHeight = Get-ConsoleHeight

    Set-Variable -Name NewPosition -Option AllScope -Value $Position

    <#
    .SYNOPSIS

    Updates the position until we aren't on a separator
    #>
    function Reset-InvalidPosition([Parameter(Mandatory)][int] $PositionOffset) {
        $NewPosition = Get-WrappedPosition $MenuItems $NewPosition $PositionOffset
    }

    If (Test-KeyUp $VKeyCode) {
        $NewPosition--

        Reset-InvalidPosition -PositionOffset -1
    }

    If (Test-KeyDown $VKeyCode) {
        $NewPosition++

        Reset-InvalidPosition -PositionOffset 1
    }

    If (Test-KeyPageDown $VKeyCode) {
        $NewPosition = [Math]::Min($MaxPosition, $NewPosition + $WindowHeight)

        Reset-InvalidPosition -PositionOffset -1
    }

    If (Test-KeyEnd $VKeyCode) {
        $NewPosition = $MenuItems.Count - 1

        Reset-InvalidPosition -PositionOffset 1
    }

    IF (Test-KeyPageUp $VKeyCode) {
        $NewPosition = [Math]::Max($MinPosition, $NewPosition - $WindowHeight)

        Reset-InvalidPosition -PositionOffset -1
    }

    IF (Test-KeyHome $VKeyCode) {
        $NewPosition = $MinPosition

        Reset-InvalidPosition -PositionOffset -1
    }

    Return $NewPosition
}

function Read-VKey() {
    $CurrentHost = Get-Host
    $ErrMsg = "Current host '$CurrentHost' does not support operation 'ReadKey'"

    try {
        # Issues with reading up and down arrow keys
        # - https://github.com/PowerShell/PowerShell/issues/16443
        # - https://github.com/dotnet/runtime/issues/63387
        # - https://github.com/PowerShell/PowerShell/issues/16606
        if ($IsLinux -or $IsMacOS) {
            ## A bug with Linux and Mac where arrow keys are return in 2 chars.  First is esc follow by A,B,C,D
            $key1 = $CurrentHost.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

            if ($key1.VirtualKeyCode -eq 0x1B) {
                ## Found that we got an esc chair so we need to grab one more char
                $key2 = $CurrentHost.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

                ## We just care about up and down arrow mapping here for now.
                if ($key2.VirtualKeyCode -eq 0x41) {
                    # VK_UP = 0x26 up-arrow
                    $key1.VirtualKeyCode = 0x26
                }
                if ($key2.VirtualKeyCode -eq 0x42) {
                    # VK_DOWN = 0x28 down-arrow
                    $key1.VirtualKeyCode = 0x28
                }
            }
            Return $key1
        }

        Return $CurrentHost.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    catch [System.NotSupportedException] {
        Write-Error -Exception $_.Exception -Message $ErrMsg
    }
    catch [System.NotImplementedException] {
        Write-Error -Exception $_.Exception -Message $ErrMsg
    }
}

$KeyConstants = [PSCustomObject]@{
    VK_RETURN   = 0x0D;
    VK_ESCAPE   = 0x1B;
    VK_UP       = 0x26;
    VK_DOWN     = 0x28;
    VK_SPACE    = 0x20;
    VK_PAGEUP   = 0x21; # Actually VK_PRIOR
    VK_PAGEDOWN = 0x22; # Actually VK_NEXT
    VK_END      = 0x23;
    VK_HOME     = 0x24;
}

function Test-KeyEnter($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_RETURN
}

function Test-KeyEscape($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_ESCAPE
}

function Test-KeyUp($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_UP
}

function Test-KeyDown($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_DOWN
}

function Test-KeySpace($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_SPACE
}

function Test-KeyPageDown($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_PAGEDOWN
}

function Test-KeyPageUp($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_PAGEUP
}

function Test-KeyEnd($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_END
}

function Test-KeyHome($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_HOME
}

function Format-MenuItem(
    [Parameter(Mandatory)] $MenuItem,
    [Switch] $MultiSelect,
    [Parameter(Mandatory)][bool] $IsItemSelected,
    [Parameter(Mandatory)][bool] $IsItemFocused) {

    $SelectionPrefix = '    '
    $FocusPrefix = '  '
    $ItemText = ' -------------------------- '

    if ($(Test-MenuSeparator $MenuItem) -ne $true) {
        if ($MultiSelect) {
            $SelectionPrefix = if ($IsItemSelected) { '[x] ' } else { '[ ] ' }
        }

        $FocusPrefix = if ($IsItemFocused) { '> ' } else { '  ' }
        $ItemText = $MenuItem.ToString()
    }

    $WindowWidth = (Get-Host).UI.RawUI.WindowSize.Width

    $Text = "{0}{1}{2}" -f $FocusPrefix, $SelectionPrefix, $ItemText
    if ($WindowWidth - ($Text.Length + 2) -gt 0) {
        $Text = $Text.PadRight($WindowWidth - ($Text.Length + 2), ' ')
    }

    Return $Text
}

function Format-MenuItemDefault($MenuItem) {
    Return $MenuItem.ToString()
}

function Get-ConsoleHeight() {
    Return (Get-Host).UI.RawUI.WindowSize.Height - 2
}

function Get-CalculatedPageIndexNumber(
    [Parameter(Mandatory, Position = 0)][Array] $MenuItems,
    [Parameter(Position = 1)][int]$MenuPosition,
    [Switch]$TopIndex,
    [Switch]$ItemCount,
    [Switch]$BottomIndex
) {
    $WindowHeight = Get-ConsoleHeight

    $TopIndexNumber = 0;
    $MenuItemCount = $MenuItems.Count

    if ($MenuItemCount -gt $WindowHeight) {
        $MenuItemCount = $WindowHeight;
        if ($MenuPosition -gt $MenuItemCount) {
            $TopIndexNumber = $MenuPosition - $MenuItemCount;
        }
    }

    if ($TopIndex) {
        Return $TopIndexNumber
    }

    if ($ItemCount) {
        Return $MenuItemCount
    }

    if ($BottomIndex) {
        Return $TopIndexNumber + [Math]::Min($MenuItemCount, $WindowHeight) - 1
    }

    Throw 'Invalid option combination'
}

function Write-MenuItem(
    [Parameter(Mandatory)][String] $MenuItem,
    [Switch]$IsFocused,
    [ConsoleColor]$FocusColor) {
    if ($IsFocused) {
        Write-Host $MenuItem -ForegroundColor $FocusColor
    }
    else {
        Write-Host $MenuItem
    }
}

function Write-Menu {
    param (
        [Parameter(Mandatory)][Array] $MenuItems,
        [Parameter(Mandatory)][Int] $MenuPosition,
        [Parameter()][Array] $CurrentSelection,
        [Parameter(Mandatory)][ConsoleColor] $ItemFocusColor,
        [Parameter(Mandatory)][ScriptBlock] $MenuItemFormatter,
        [Switch] $MultiSelect
    )

    $CurrentIndex = Get-CalculatedPageIndexNumber -MenuItems $MenuItems -MenuPosition $MenuPosition -TopIndex
    $MenuItemCount = Get-CalculatedPageIndexNumber -MenuItems $MenuItems -MenuPosition $MenuPosition -ItemCount
    $ConsoleWidth = [Console]::BufferWidth
    $MenuHeight = 0

    for ($i = 0; $i -le $MenuItemCount; $i++) {
        if ($null -eq $MenuItems[$CurrentIndex]) {
            Continue
        }

        $RenderMenuItem = $MenuItems[$CurrentIndex]
        $MenuItemStr = if (Test-MenuSeparator $RenderMenuItem) { $RenderMenuItem } else { & $MenuItemFormatter $RenderMenuItem }
        if (!$MenuItemStr) {
            Throw "'MenuItemFormatter' returned an empty string for item #$CurrentIndex"
        }

        $IsItemSelected = $CurrentSelection -contains $CurrentIndex
        $IsItemFocused = $CurrentIndex -eq $MenuPosition

        $DisplayText = Format-MenuItem -MenuItem $MenuItemStr -MultiSelect:$MultiSelect -IsItemSelected:$IsItemSelected -IsItemFocused:$IsItemFocused
        Write-MenuItem -MenuItem $DisplayText -IsFocused:$IsItemFocused -FocusColor $ItemFocusColor
        $MenuHeight += [Math]::Max([Math]::Ceiling($DisplayText.Length / $ConsoleWidth), 1)

        $CurrentIndex++;
    }

    $MenuHeight
}

function  Get-WrappedPosition([Array]$MenuItems, [int]$Position, [int]$PositionOffset) {
    # Wrap position
    if ($Position -lt 0) {
        $Position = $MenuItems.Count - 1
    }

    if ($Position -ge $MenuItems.Count) {
        $Position = 0
    }

    # Ensure to skip separators
    while (Test-MenuSeparator $($MenuItems[$Position])) {
        $Position += $PositionOffset

        $Position = Get-WrappedPosition $MenuItems $Position $PositionOffset
    }

    Return $Position
}

$Separator = [PSCustomObject]@{
    __MarkSeparator = [Guid]::NewGuid()
}

function Get-MenuSeparator() {
    [CmdletBinding()]
    Param()

    # Internally we will check this parameter by-reference
    Return $Separator
}

function Test-HostSupported() {
    $Whitelist = @("ConsoleHost")

    if ($Whitelist -inotcontains $Host.Name) {
        Throw "This host is $($Host.Name) and does not support an interactive menu."
    }
}

function Test-MenuSeparator([Parameter(Mandatory)] $MenuItem) {
    $Separator = Get-MenuSeparator

    # Separator is a singleton and we compare it by reference
    Return [Object]::ReferenceEquals($Separator, $MenuItem)
}

function Test-MenuItemArray([Array]$MenuItems) {
    foreach ($MenuItem in $MenuItems) {
        $IsSeparator = Test-MenuSeparator $MenuItem
        if ($IsSeparator -eq $false) {
            Return
        }
    }

    Throw 'The -MenuItems option only contains non-selectable menu-items (like separators)'
}

function Show-Menu {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, Position = 0)][Array] $MenuItems,
        [Switch]$ReturnIndex,
        [Switch]$MultiSelect,
        [ConsoleColor] $ItemFocusColor = [ConsoleColor]::Green,
        [ScriptBlock] $MenuItemFormatter = { Param($M) Format-MenuItemDefault $M }
    )

    Test-HostSupported
    Test-MenuItemArray -MenuItems $MenuItems

    # Current pressed virtual key code
    $VKeyCode = 0

    # Initialize valid position
    $Position = Get-WrappedPosition $MenuItems -Position 0 -PositionOffset 1

    $CurrentSelection = @()
    $CursorPosition = [System.Console]::CursorTop

    try {
        [System.Console]::CursorVisible = $False # Prevents cursor flickering

        # Body
        $WriteMenu = {
            ([ref]$MenuHeight).Value = Write-Menu -MenuItems $MenuItems `
                -MenuPosition $Position `
                -MultiSelect:$MultiSelect `
                -CurrentSelection:$CurrentSelection `
                -ItemFocusColor $ItemFocusColor `
                -MenuItemFormatter $MenuItemFormatter
        }
        $MenuHeight = 0

        & $WriteMenu
        While ($True) {
            If (Test-KeyEscape $VKeyCode) {
                Return $null
            }

            if (Test-KeyEnter $VKeyCode) {
                Break
            }

            $CurrentPress = Read-VKey
            $VKeyCode = $CurrentPress.VirtualKeyCode

            If (Test-KeySpace $VKeyCode) {
                $CurrentSelection = Toggle-Selection $Position $CurrentSelection
            }

            $Position = Get-PositionWithVKey -MenuItems $MenuItems -Position $Position -VKeyCode $VKeyCode

            If (!$(Test-KeyEscape $VKeyCode)) {
                [System.Console]::SetCursorPosition(0, [Console]::CursorTop - $MenuHeight)
                & $WriteMenu
            }
        }
    }
    finally {
        [System.Console]::CursorVisible = $true
    }

    if ($ReturnIndex -eq $false -and $null -ne $Position) {
        if ($MultiSelect) {
            Return $MenuItems[$CurrentSelection]
        }
        else {
            Return $MenuItems[$Position]
        }
    }
    else {
        if ($MultiSelect) {
            Return $CurrentSelection
        }
        else {
            Return $Position
        }
    }
}

### End stolen code from https://github.com/Sebazzz/PSMenu/

### Stolen from https://github.com/kdoblosky/PShr/blob/master/Get-HorizontalLine.ps1
Function Get-HorizontalLine {
    param (
        [string]$InputString = "-",
        [parameter(Mandatory = $false)][alias("c")]$Count = 1,
        [parameter(Mandatory = $false)][alias("fg")]$ForeColor = $null,
        [parameter(Mandatory = $false)][alias("bg")]$BackColor = $null
    )
    $ColorSplat = @{}
    if ($ForeColor -ne $null) { $ColorSplat.ForegroundColor = $ForeColor }
    if ($BackColor -ne $null) { $ColorSplat.BackgroundColor = $BackColor }

    # How long to make the hr
    $width = if ($host.Name -match "ISE") {
        $host.UI.RawUI.BufferSize.Width - 1
    }
    else {
        $host.UI.RawUI.BufferSize.Width - 4
    }


    # How many times to repeat $Character in full
    $repetitions = [System.Math]::Floor($width / $InputString.Length)

    # How many characters of $InputString to add to fill each line
    $remainder = $width - ($InputString.Length * $repetitions)

    # Make line(s)
    1..$Count | % {
        Write-Host ($InputString * $repetitions) + $InputString.Substring(0, $remainder) @ColorSplat
    }
}
### End stolen from https://github.com/kdoblosky/PShr/blob/master/Get-HorizontalLine.ps1

Main
