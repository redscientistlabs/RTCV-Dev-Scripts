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

    # Repos to clone
    [string[]]$repos = @(),

    # Clone all of the repos
    [switch]$all = $false,
    # TODO - Building on clone may be nice for some devs.
    # [switch]$build = $false,

    # Swallow all remaining arguments. This avoids commands like:
    #  .\setup.ps1 -repos RTCV dolphin-vanguard
    # From assigning "dolphin-vanguard" to the "directory" parameter. Powershell 😡
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)] $extraArgs
)

function Main () {
    Test-Prerequisites

    Write-Host "Writing to:`t$directory" -ForegroundColor Blue

    if ($all) {
        $repos = Get-AllRepos
    }
    elseif ($repos.Count -ne 0) {
        Remove-InvalidRepos($repos)
    }
    else {
        $repos = Prompt-UserForRepos
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
    # xemu is a prototype that needs more work and is dependent on RTCVDLLHOOK
    # "xemu-Vanguard"         = "master";
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
    for ($i = 0; $i -lt $repos.Count; $i++) {
        $repo = $repos[$i]
        if (-not $ValidRepos.Contains($repo)) {
            Write-Host "Invalid repo: '$repo'. Skipping..." -ForegroundColor Yellow
            $repos.Remove($repo)
        }
    }
}

function Prompt-UserForRepos {
    # $result = $ValidRepos.Keys | Out-GridView -OutputMode Multiple
    $options = $ValidRepos.Keys | ForEach-Object { $_ }
    Write-Host "Select repos to clone:" -ForegroundColor Blue
    Show-Menu $options -MultiSelect
    return @()
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

Main
