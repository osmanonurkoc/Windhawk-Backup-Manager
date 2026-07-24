<#
    .SYNOPSIS
    Windhawk Backup Manager

    .DESCRIPTION
    A modern WPF-based utility designed to seamlessly backup, review, and restore
    Windhawk mods, compiled engine binaries, and registry configurations.

    Key Features:
    - Registry-Driven Listing: Pulls exact active mods straight from the registry without duplicates.
    - Complete Source Backup: Backs up ALL selected mod source files to prevent Update Available errors.
    - Precision Binary Export: Bundles compiled engine binaries mapped accurately via LibraryFileName.
    - Selective Registry Backup: Parses the exported registry file and strips out settings for unselected mods.
    - Selective Registry Restore: Filters the registry file during restore to strictly import only the chosen mods.
    - Fluent Design UI: WinUI3 style toggle switches, modern scrollbars, and dynamic mode transitions.
    - Safe Execution: Temporarily manages Windhawk service states to prevent file locking issues.
    - Silent Native Execution: Suppresses all native reg.exe streams to prevent console errors.
    - Theme Engine: Auto-detects System Light/Dark mode with native Win11 DWM titlebar styling.

    .AUTHOR
    @osmanonurkoc
    Website: https://www.osmanonurkoc.com
#>

# =============================================================================
# 1. PRIVILEGE CHECK
# =============================================================================
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs -ArgumentList "-WindowStyle Hidden -File `"$($MyInvocation.MyCommand.Path)`""
    Exit
}

# =============================================================================
# 2. LOAD ASSEMBLIES & WIN32 API
# =============================================================================
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not ("Win32Tools" -as [type])) {
    $Win32Code = @'
        using System;
        using System.Runtime.InteropServices;

        public class Win32Tools {
            [DllImport("dwmapi.dll", PreserveSig = true)]
            public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

            [DllImport("user32.dll", CharSet = CharSet.Auto)]
            public static extern IntPtr SendMessage(IntPtr hWnd, UInt32 Msg, IntPtr wParam, IntPtr lParam);
        }
'@
    Add-Type -TypeDefinition $Win32Code -Language CSharp
}

# =============================================================================
# 3. ICON & ASSETS
# =============================================================================
$AppIconBase64 = "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"

$IconBitmap = $null
if (![string]::IsNullOrEmpty($AppIconBase64)) {
    try {
        $Bytes = [Convert]::FromBase64String($AppIconBase64)
        $MemStream = New-Object System.IO.MemoryStream(,$Bytes)
        $IconBitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $IconBitmap.BeginInit()
        $IconBitmap.StreamSource = $MemStream
        $IconBitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $IconBitmap.EndInit()
    } catch {}
}

# =============================================================================
# 4. THEME LOGIC
# =============================================================================
function Get-SystemTheme {
    try {
        $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        $isLight = (Get-ItemProperty -Path $regKey -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue).AppsUseLightTheme
        return if ($isLight -eq 1) { "Light" } else { "Dark" }
    } catch { return "Dark" }
}

$CurrentTheme = Get-SystemTheme
$Themes = @{
    "Dark" = @{
        "Bg" = "#202020"; "Surface" = "#2C2C2C"; "Text" = "#FFFFFF"; "SubText" = "#AAAAAA";
        "Border" = "#404040"; "Accent" = "#60CDFF"; "BtnBg" = "#333333"; "BtnHover" = "#444444";
        "RestoreAccent" = "#FF99A4"; "ToggleOff" = "#333333"; "Green" = "#32D74B"; "Red" = "#FF453A"
    }
    "Light" = @{
        "Bg" = "#F3F3F3"; "Surface" = "#FFFFFF"; "Text" = "#000000"; "SubText" = "#666666";
        "Border" = "#E5E5E5"; "Accent" = "#005FB8"; "BtnBg" = "#FFFFFF"; "BtnHover" = "#E5E5E5";
        "RestoreAccent" = "#C50F1F"; "ToggleOff" = "#F3F3F3"; "Green" = "#107C10"; "Red" = "#E81123"
    }
}
$ThemeObj = $Themes[$CurrentTheme]

# =============================================================================
# 5. XAML UI DESIGN
# =============================================================================
$Xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windhawk Backup Manager"
        Height="580" Width="420"
        WindowStartupLocation="CenterScreen"
        FontFamily="Segoe UI Variable, Segoe UI, Arial"
        ResizeMode="NoResize"
        WindowStyle="SingleBorderWindow"
        Background="{DynamicResource BgBrush}">

    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="{DynamicResource BtnBgBrush}"/>
            <Setter Property="Foreground" Value="{DynamicResource TextBrush}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource BorderBrush}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10"/>
            <Setter Property="Margin" Value="0,5,0,5"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{DynamicResource BtnHoverBrush}"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="FluentToggle" TargetType="CheckBox">
            <Setter Property="Foreground" Value="{DynamicResource TextBrush}"/>
            <Setter Property="Margin" Value="0,6,0,6"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Grid Background="Transparent">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Border x:Name="ToggleBorder" Grid.Column="0" Width="38" Height="20" CornerRadius="10" Background="{DynamicResource ToggleOffBrush}" BorderBrush="{DynamicResource SubTextBrush}" BorderThickness="1.5" VerticalAlignment="Center" Margin="0,0,12,0">
                                <Ellipse x:Name="ToggleThumb" Width="12" Height="12" Fill="{DynamicResource SubTextBrush}" HorizontalAlignment="Left" Margin="3,0,0,0"/>
                            </Border>
                            <ContentPresenter Grid.Column="1" VerticalAlignment="Center"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="ToggleBorder" Property="Background" Value="{DynamicResource AccentBrush}"/>
                                <Setter TargetName="ToggleBorder" Property="BorderBrush" Value="{DynamicResource AccentBrush}"/>
                                <Setter TargetName="ToggleThumb" Property="Fill" Value="{DynamicResource BgBrush}"/>
                                <Setter TargetName="ToggleThumb" Property="Margin" Value="21,0,0,0"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ToggleBorder" Property="BorderBrush" Value="{DynamicResource TextBrush}"/>
                            </Trigger>
                            <MultiTrigger>
                                <MultiTrigger.Conditions>
                                    <Condition Property="IsChecked" Value="True"/>
                                    <Condition Property="IsMouseOver" Value="True"/>
                                </MultiTrigger.Conditions>
                                <Setter TargetName="ToggleThumb" Property="Fill" Value="{DynamicResource SurfaceBrush}"/>
                            </MultiTrigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Width" Value="6"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Grid Background="{TemplateBinding Background}">
                            <Track Name="PART_Track" IsDirectionReversed="true">
                                <Track.Thumb>
                                    <Thumb>
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb">
                                                <Border CornerRadius="3" Background="{DynamicResource SubTextBrush}" Opacity="0.4" Margin="0,2,0,2"/>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="25">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="25"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Margin="0,0,0,25" Cursor="Hand" Name="BannerLink">
            <Image Name="LogoImage" Width="56" Height="56" HorizontalAlignment="Center" Margin="0,0,0,10"/>
            <TextBlock Text="Windhawk Backup Manager" FontSize="18" FontWeight="SemiBold" Foreground="{DynamicResource TextBrush}" HorizontalAlignment="Center"/>
            <TextBlock Text="@osmanonurkoc" FontSize="13" Foreground="{DynamicResource SubTextBrush}" HorizontalAlignment="Center" Margin="0,2,0,0"/>
        </StackPanel>

        <StackPanel Grid.Row="1" Margin="0,0,0,10">
            <TextBlock Name="TxtTitle" Text="Installed Mods (Backup Mode)" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextBrush}" Margin="0,0,0,12"/>
            <CheckBox Name="ChkSelectAll" Content="Select All / Clear" IsChecked="True" Style="{StaticResource FluentToggle}"/>
        </StackPanel>

        <Border Name="ModListBorder" Grid.Row="2" Background="{DynamicResource SurfaceBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="8" Padding="15" Margin="0,0,0,15">
            <ScrollViewer VerticalScrollBarVisibility="Auto">
                <StackPanel Name="ModListPanel"/>
            </ScrollViewer>
        </Border>

        <StackPanel Name="ActionPanel" Grid.Row="3">
            <Button Name="BtnBackup" Content="Export Selected (Backup)"/>
            <Button Name="BtnSelectZip" Content="Import (Select ZIP)"/>
        </StackPanel>

        <StackPanel Name="RestorePanel" Grid.Row="3" Visibility="Collapsed">
            <Button Name="BtnConfirmRestore" Content="Confirm and Install Selected" FontWeight="SemiBold" Background="{DynamicResource AccentBrush}" Foreground="{DynamicResource BgBrush}"/>
            <Button Name="BtnCancelRestore" Content="Cancel (Return to Backup Mode)"/>
        </StackPanel>

        <TextBlock Name="TxtStatus" Grid.Row="4" Text="System scanned, ready." VerticalAlignment="Bottom" HorizontalAlignment="Center" Foreground="{DynamicResource SubTextBrush}" FontSize="12"/>
    </Grid>
</Window>
'@

# =============================================================================
# 6. UI INITIALIZATION & EVENTS
# =============================================================================
[xml]$xmlDoc = $Xaml
$Reader = (New-Object System.Xml.XmlNodeReader ($xmlDoc))
$Window = [Windows.Markup.XamlReader]::Load($Reader)

if ($IconBitmap) { $Window.Icon = $IconBitmap }

$Res = $Window.Resources
$Convert = { param($Hex) return (New-Object System.Windows.Media.BrushConverter).ConvertFromString($Hex) }
$Res["BgBrush"]           = &$Convert $ThemeObj.Bg
$Res["SurfaceBrush"]      = &$Convert $ThemeObj.Surface
$Res["TextBrush"]         = &$Convert $ThemeObj.Text
$Res["SubTextBrush"]      = &$Convert $ThemeObj.SubText
$Res["BorderBrush"]       = &$Convert $ThemeObj.Border
$Res["AccentBrush"]       = &$Convert $ThemeObj.Accent
$Res["BtnBgBrush"]        = &$Convert $ThemeObj.BtnBg
$Res["BtnHoverBrush"]     = &$Convert $ThemeObj.BtnHover
$Res["RestoreAccentBrush"]= &$Convert $ThemeObj.RestoreAccent
$Res["ToggleOffBrush"]    = &$Convert $ThemeObj.ToggleOff
$Res["GreenBrush"]        = &$Convert $ThemeObj.Green
$Res["RedBrush"]          = &$Convert $ThemeObj.Red

$BannerLink = $Window.FindName("BannerLink")
$LogoImage = $Window.FindName("LogoImage")
$ModListPanel = $Window.FindName("ModListPanel")
$ModListBorder = $Window.FindName("ModListBorder")
$ChkSelectAll = $Window.FindName("ChkSelectAll")
$BtnBackup = $Window.FindName("BtnBackup")
$BtnSelectZip = $Window.FindName("BtnSelectZip")
$BtnConfirmRestore = $Window.FindName("BtnConfirmRestore")
$BtnCancelRestore = $Window.FindName("BtnCancelRestore")
$ActionPanel = $Window.FindName("ActionPanel")
$RestorePanel = $Window.FindName("RestorePanel")
$TxtTitle = $Window.FindName("TxtTitle")
$TxtStatus = $Window.FindName("TxtStatus")

if ($IconBitmap) { $LogoImage.Source = $IconBitmap }

$whProgramData = "C:\ProgramData\Windhawk"
$tempDir = Join-Path $env:TEMP "WindhawkBackupTemp"
$restoreTempDir = Join-Path $env:TEMP "WindhawkRestoreTemp"

# Hash table to store ModName -> LibraryFileName mapping
$script:ModToFileMap = @{}

function Populate-ModList {
    param([string]$SourcePath)
    if ($ModListPanel) { $ModListPanel.Children.Clear() }
    $script:ModToFileMap.Clear()
    $modsFound = $false
    $modNames = [System.Collections.Generic.HashSet[string]]::New([StringComparer]::OrdinalIgnoreCase)

    if ($SourcePath -eq $whProgramData) {
        $regPaths = @("HKLM:\SOFTWARE\Windhawk\Engine\Mods", "HKLM:\SOFTWARE\Windhawk\Mods")
        foreach ($regPath in $regPaths) {
            if (Test-Path $regPath) {
                foreach ($subKey in (Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue)) {
                    $modName = $subKey.PSChildName
                    $libFile = (Get-ItemProperty -Path $subKey.PSPath -Name "LibraryFileName" -ErrorAction SilentlyContinue).LibraryFileName
                    if ($libFile) {
                        $script:ModToFileMap[$modName] = $libFile
                        [void]$modNames.Add($modName)
                    }
                }
            }
        }
    } else {
        # Read from ZIP: parse the reg file inside the zip and extract the LibraryFileName mapping
        $regFile = Join-Path $SourcePath "windhawk_reg.reg"
        if (Test-Path $regFile) {
            $regContent = Get-Content $regFile -Encoding UTF8 -ErrorAction SilentlyContinue
            $currentMod = $null
            foreach ($line in $regContent) {
                if ($line -match '^\[HKEY_LOCAL_MACHINE\\SOFTWARE\\Windhawk\\Engine\\Mods\\(.+)\]$') {
                    $currentMod = $Matches[1]
                } elseif ($line -match '^"LibraryFileName"="(.+)"$') {
                    if ($currentMod) {
                        $script:ModToFileMap[$currentMod] = $Matches[1]
                        [void]$modNames.Add($currentMod)
                        $currentMod = $null
                    }
                }
            }
        }
    }

    foreach ($modName in $modNames | Sort-Object) {
        if ([string]::IsNullOrWhiteSpace($modName)) { continue }
        $modsFound = $true
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = $modName
        $cb.IsChecked = $ChkSelectAll.IsChecked
        $cb.Style = $Window.FindResource("FluentToggle")
        if ($ModListPanel) { [void]$ModListPanel.Children.Add($cb) }
    }

    if (-not $modsFound -and $ModListPanel) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = "No mods found."
        $tb.Foreground = $Res["SubTextBrush"]
        $tb.Opacity = 0.8
        [void]$ModListPanel.Children.Add($tb)
    }
}

Populate-ModList -SourcePath $whProgramData

if ($ChkSelectAll) {
    $ChkSelectAll.Add_Click({
        $state = $ChkSelectAll.IsChecked
        foreach ($child in $ModListPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                $child.IsChecked = $state
            }
        }
    })
}

if ($BtnBackup) {
    $BtnBackup.Add_Click({
        $selectedMods = @()
        foreach ($child in $ModListPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked -eq $true) {
                $selectedMods += $child.Content
            }
        }

        if ($selectedMods.Count -eq 0) {
            $TxtStatus.Text = "Please select at least one mod!"
            $TxtStatus.Foreground = $Res["RedBrush"]
            return
        }

        $dialog = New-Object System.Windows.Forms.SaveFileDialog
        $dialog.Filter = "ZIP File (*.zip)|*.zip"
        $dialog.FileName = "WindhawkBackup_$(Get-Date -Format 'yyyyMMdd').zip"

        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $TxtStatus.Text = "Backing up selected mods..."
            $TxtStatus.Foreground = $Res["TextBrush"]
            $Window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)

            try {
                if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
                New-Item -ItemType Directory -Path "$tempDir\Engine\Mods" | Out-Null
                New-Item -ItemType Directory -Path "$tempDir\ModsSource" | Out-Null

                Stop-Service -Name "WindhawkService" -Force -ErrorAction SilentlyContinue

                # 1. Export the full registry to a temporary file
                $fullRegPath = Join-Path $tempDir "full_windhawk.reg"
                $filteredRegPath = Join-Path $tempDir "windhawk_reg.reg"
                Start-Process -FilePath "reg.exe" -ArgumentList "export `"HKLM\SOFTWARE\Windhawk`" `"$fullRegPath`" /y" -WindowStyle Hidden -Wait

                # 2. Filter registry entries of unselected mods
                $regLines = [System.IO.File]::ReadAllLines($fullRegPath)
                $filteredLines = New-Object System.Collections.Generic.List[string]
                $keepCurrentKey = $true

                foreach ($line in $regLines) {
                    if ($line -match '^\[(.+)\]$') {
                        $keyPath = $Matches[1]
                        # If we are inside a mod folder under Mods or ModsWritable
                        if ($keyPath -match 'SOFTWARE\\Windhawk\\Engine\\(?:Mods|ModsWritable)\\([^\\]+)') {
                            $modName = $Matches[1]
                            if ($selectedMods -contains $modName) {
                                $keepCurrentKey = $true
                            } else {
                                $keepCurrentKey = $false
                            }
                        } else {
                            # Include core settings folders (Settings, Engine, etc.) in the backup
                            $keepCurrentKey = $true
                        }
                    }

                    if ($keepCurrentKey) {
                        $filteredLines.Add($line)
                    }
                }

                # Save the cleaned/filtered registry file (Unicode encoding is mandatory for REG format)
                [System.IO.File]::WriteAllLines($filteredRegPath, $filteredLines, [System.Text.Encoding]::Unicode)
                Remove-Item $fullRegPath -Force -ErrorAction SilentlyContinue

                # 3. Copy files
                foreach ($mod in $selectedMods) {
                    # 1. COMPLETE SOURCE CODE BACKUP: Backup source codes for all selected mods
                    Get-ChildItem -Path "$whProgramData\ModsSource" -ErrorAction SilentlyContinue | Where-Object {
                        $_.BaseName -eq $mod -or $_.BaseName -eq "$mod.wh"
                    } | ForEach-Object {
                        Copy-Item -Path $_.FullName -Destination "$tempDir\ModsSource" -Force -ErrorAction SilentlyContinue
                    }

                    # 2. COMPILED BINARY BACKUP: Backup compiled mod files based on matching LibraryFileName
                    $libFile = $script:ModToFileMap[$mod]
                    if ($libFile) {
                        Get-ChildItem -Path "$whProgramData\Engine\Mods" -Recurse -Filter $libFile -ErrorAction SilentlyContinue | ForEach-Object {
                            $rel = $_.FullName.Substring("$whProgramData\Engine\Mods\".Length)
                            $dest = Join-Path "$tempDir\Engine\Mods" (Split-Path $rel -Parent)
                            if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
                            Copy-Item -Path $_.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
                        }
                    }
                }

                # If no files were added to the ModsSource folder, delete it to prevent an empty folder in the zip
                if ((Get-ChildItem -Path "$tempDir\ModsSource").Count -eq 0) {
                    Remove-Item -Path "$tempDir\ModsSource" -Force -ErrorAction SilentlyContinue
                }

                if (Test-Path $dialog.FileName) { Remove-Item $dialog.FileName -Force }
                Compress-Archive -Path "$tempDir\*" -DestinationPath $dialog.FileName -Force

                $TxtStatus.Text = "$($selectedMods.Count) mods backed up successfully!"
                $TxtStatus.Foreground = $Res["GreenBrush"]
            } catch {
                $TxtStatus.Text = "Error: $($_.Exception.Message)"
                $TxtStatus.Foreground = $Res["RedBrush"]
            } finally {
                Start-Service -Name "WindhawkService" -ErrorAction SilentlyContinue
                if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
            }
        }
    })
}

if ($BtnSelectZip) {
    $BtnSelectZip.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Filter = "ZIP File (*.zip)|*.zip"

        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $TxtStatus.Text = "Reading ZIP, listing mods..."
            $TxtStatus.Foreground = $Res["TextBrush"]
            $Window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)

            try {
                if (Test-Path $restoreTempDir) { Remove-Item $restoreTempDir -Recurse -Force }
                New-Item -ItemType Directory -Path $restoreTempDir | Out-Null
                Expand-Archive -Path $dialog.FileName -DestinationPath $restoreTempDir -Force

                Populate-ModList -SourcePath $restoreTempDir

                $TxtTitle.Text = "Restore Mode (Review Mods)"
                $TxtTitle.Foreground = $Res["RestoreAccentBrush"]
                $ModListBorder.BorderBrush = $Res["RestoreAccentBrush"]
                $ModListBorder.BorderThickness = "1.5"

                $ActionPanel.Visibility = "Collapsed"
                $RestorePanel.Visibility = "Visible"
                $TxtStatus.Text = "ZIP read successfully. Please select mods to install."
                $TxtStatus.Foreground = $Res["GreenBrush"]
            } catch {
                $TxtStatus.Text = "ZIP reading error: $($_.Exception.Message)"
                $TxtStatus.Foreground = $Res["RedBrush"]
            }
        }
    })
}

if ($BtnCancelRestore) {
    $BtnCancelRestore.Add_Click({
        Populate-ModList -SourcePath $whProgramData

        $TxtTitle.Text = "Installed Mods (Backup Mode)"
        $TxtTitle.Foreground = $Res["TextBrush"]
        $ModListBorder.BorderBrush = $Res["BorderBrush"]
        $ModListBorder.BorderThickness = "1"

        $ActionPanel.Visibility = "Visible"
        $RestorePanel.Visibility = "Collapsed"
        $TxtStatus.Text = "Operation cancelled, listing installed mods."
        $TxtStatus.Foreground = $Res["TextBrush"]
        if (Test-Path $restoreTempDir) { Remove-Item $restoreTempDir -Recurse -Force }
    })
}

if ($BtnConfirmRestore) {
    $BtnConfirmRestore.Add_Click({
        $selectedMods = @()
        foreach ($child in $ModListPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked -eq $true) {
                $selectedMods += $child.Content
            }
        }

        if ($selectedMods.Count -eq 0) {
            $TxtStatus.Text = "Please select at least one mod to install!"
            $TxtStatus.Foreground = $Res["RedBrush"]
            return
        }

        $TxtStatus.Text = "Restoring mods and registry..."
        $TxtStatus.Foreground = $Res["TextBrush"]
        $Window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)

        try {
            Stop-Service -Name "WindhawkService" -Force -ErrorAction SilentlyContinue

            if (Test-Path "$restoreTempDir\windhawk_reg.reg") {
                # 1. SMART REGISTRY RESTORE: Filter the registry file to strictly import only the chosen mods
                $regLines = [System.IO.File]::ReadAllLines("$restoreTempDir\windhawk_reg.reg")
                $filteredLines = New-Object System.Collections.Generic.List[string]
                $keepCurrentKey = $true

                foreach ($line in $regLines) {
                    if ($line -match '^\[(.+)\]$') {
                        $keyPath = $Matches[1]
                        # If we are inside a mod folder under Mods or ModsWritable
                        if ($keyPath -match 'SOFTWARE\\Windhawk\\Engine\\(?:Mods|ModsWritable)\\([^\\]+)') {
                            $modName = $Matches[1]
                            if ($selectedMods -contains $modName) {
                                $keepCurrentKey = $true
                            } else {
                                $keepCurrentKey = $false
                            }
                        } else {
                            # Include core settings folders (Settings, Engine, etc.)
                            $keepCurrentKey = $true
                        }
                    }

                    if ($keepCurrentKey) {
                        $filteredLines.Add($line)
                    }
                }

                $filteredRegPath = Join-Path $restoreTempDir "filtered_restore.reg"
                [System.IO.File]::WriteAllLines($filteredRegPath, $filteredLines, [System.Text.Encoding]::Unicode)

                # Import the strictly filtered registry file
                Start-Process -FilePath "reg.exe" -ArgumentList "import `"$filteredRegPath`"" -WindowStyle Hidden -Wait
            }

            if (-not (Test-Path "$whProgramData\ModsSource")) { New-Item -ItemType Directory -Path "$whProgramData\ModsSource" | Out-Null }
            if (-not (Test-Path "$whProgramData\Engine\Mods")) { New-Item -ItemType Directory -Path "$whProgramData\Engine\Mods" | Out-Null }

            foreach ($mod in $selectedMods) {
                # 2. Restore local source codes (if any)
                if (Test-Path "$restoreTempDir\ModsSource") {
                    Get-ChildItem -Path "$restoreTempDir\ModsSource" -ErrorAction SilentlyContinue | Where-Object {
                        $_.BaseName -eq $mod -or $_.BaseName -eq "$mod.wh"
                    } | ForEach-Object {
                        Copy-Item -Path $_.FullName -Destination "$whProgramData\ModsSource" -Force -ErrorAction SilentlyContinue
                    }
                }

                # 3. Restore compiled mod DLL files with exact LibraryFileName match
                $libFile = $script:ModToFileMap[$mod]
                if ($libFile -and (Test-Path "$restoreTempDir\Engine\Mods")) {
                    Get-ChildItem -Path "$restoreTempDir\Engine\Mods" -Recurse -Filter $libFile -ErrorAction SilentlyContinue | ForEach-Object {
                        $rel = $_.FullName.Substring("$restoreTempDir\Engine\Mods\".Length)
                        $dest = Join-Path "$whProgramData\Engine\Mods" (Split-Path $rel -Parent)
                        if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
                        Copy-Item -Path $_.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            $TxtStatus.Text = "$($selectedMods.Count) mods installed successfully!"
            $TxtStatus.Foreground = $Res["GreenBrush"]
            Populate-ModList -SourcePath $whProgramData

            $TxtTitle.Text = "Installed Mods (Backup Mode)"
            $TxtTitle.Foreground = $Res["TextBrush"]
            $ModListBorder.BorderBrush = $Res["BorderBrush"]
            $ModListBorder.BorderThickness = "1"

            $ActionPanel.Visibility = "Visible"
            $RestorePanel.Visibility = "Collapsed"

            # Create a modern Fluent dialog to prompt for Logoff using Grid layout for perfectly sized buttons
            $dialogXaml = @'
            <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    Title="Action Required" Width="480" SizeToContent="Height" MinHeight="180"
                    WindowStartupLocation="CenterOwner" ResizeMode="NoResize"
                    WindowStyle="ToolWindow" Background="{DynamicResource BgBrush}">
                <Window.Resources>
                    <Style TargetType="Button">
                        <Setter Property="Height" Value="36"/>
                        <Setter Property="Cursor" Value="Hand"/>
                        <Setter Property="Template">
                            <Setter.Value>
                                <ControlTemplate TargetType="Button">
                                    <Border Background="{TemplateBinding Background}"
                                            BorderBrush="{TemplateBinding BorderBrush}"
                                            BorderThickness="{TemplateBinding BorderThickness}"
                                            CornerRadius="4">
                                        <TextBlock Text="{TemplateBinding Content}"
                                                   Foreground="{TemplateBinding Foreground}"
                                                   HorizontalAlignment="Center"
                                                   VerticalAlignment="Center"/>
                                    </Border>
                                </ControlTemplate>
                            </Setter.Value>
                        </Setter>
                        <Style.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Opacity" Value="0.85"/>
                            </Trigger>
                        </Style.Triggers>
                    </Style>
                </Window.Resources>
                <Grid Margin="25">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <Path Grid.Column="0" Grid.Row="0"
                          Data="M 0,10 L 5,15 L 14,0"
                          Stroke="{DynamicResource GreenBrush}"
                          StrokeThickness="4"
                          StrokeStartLineCap="Round"
                          StrokeEndLineCap="Round"
                          StrokeLineJoin="Round"
                          VerticalAlignment="Center"
                          Margin="10,0,25,0"
                          Width="24" Height="20"
                          Stretch="Uniform"/>

                    <StackPanel Grid.Column="1" Grid.Row="0" VerticalAlignment="Center">
                        <TextBlock Text="Restore completed successfully!"
                                   FontWeight="SemiBold"
                                   FontSize="16"
                                   Foreground="{DynamicResource TextBrush}"
                                   Margin="0,0,0,8"/>
                        <TextBlock TextWrapping="Wrap"
                                   Foreground="{DynamicResource TextBrush}"
                                   FontSize="13"
                                   LineHeight="20">
                            A session logoff is highly recommended. Running applications hold memory locks on injected mod files. Please log off and log back in to ensure all mods apply correctly.
                        </TextBlock>
                    </StackPanel>

                    <Grid Grid.Row="1" Grid.ColumnSpan="2" HorizontalAlignment="Right" Margin="0,30,0,0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="120"/>
                            <ColumnDefinition Width="10"/>
                            <ColumnDefinition Width="120"/>
                        </Grid.ColumnDefinitions>

                        <Button Name="BtnLogOff" Grid.Column="0"
                                Content="Log Off"
                                Background="{DynamicResource AccentBrush}"
                                Foreground="#000000"
                                BorderThickness="0"/>

                        <Button Name="BtnLater" Grid.Column="2"
                                Content="Later"
                                Background="{DynamicResource BtnBgBrush}"
                                Foreground="{DynamicResource TextBrush}"
                                BorderBrush="{DynamicResource BorderBrush}"
                                BorderThickness="1"/>
                    </Grid>
                </Grid>
            </Window>
'@
            [xml]$dialogXmlDoc = $dialogXaml
            $dialogReader = (New-Object System.Xml.XmlNodeReader ($dialogXmlDoc))
            $dialogWindow = [Windows.Markup.XamlReader]::Load($dialogReader)
            $dialogWindow.Owner = $Window
            $dialogWindow.Resources = $Res

            $dialogWindow.Add_SourceInitialized({
                try {
                    $InteropHelper = New-Object System.Windows.Interop.WindowInteropHelper($dialogWindow)
                    $Hwnd = $InteropHelper.Handle
                    if ($CurrentTheme -eq "Dark") {
                        $Val = 1
                        [void][Win32Tools]::DwmSetWindowAttribute($Hwnd, 20, [ref]$Val, 4)
                    }
                    $CornerVal = 2
                    [void][Win32Tools]::DwmSetWindowAttribute($Hwnd, 33, [ref]$CornerVal, 4)
                } catch { }
            })

            $BtnLogOff = $dialogWindow.FindName("BtnLogOff")
            $BtnLater = $dialogWindow.FindName("BtnLater")

            $BtnLogOff.Add_Click({
                $dialogWindow.DialogResult = $true
                $dialogWindow.Close()
                logoff
            })

            $BtnLater.Add_Click({
                $dialogWindow.DialogResult = $false
                $dialogWindow.Close()
                $whInstallDir = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Windhawk" -Name "InstallDir" -ErrorAction SilentlyContinue).InstallDir
                if (-not $whInstallDir) { $whInstallDir = "$env:ProgramFiles\Windhawk" }
                $whExe = Join-Path $whInstallDir "windhawk.exe"
                if (Test-Path $whExe) {
                    Start-Process -FilePath $whExe -ErrorAction SilentlyContinue
                }
            })

            [void]$dialogWindow.ShowDialog()

        } catch {
            $TxtStatus.Text = "Installation error: $($_.Exception.Message)"
            $TxtStatus.Foreground = $Res["RedBrush"]
        } finally {
            Start-Service -Name "WindhawkService" -ErrorAction SilentlyContinue
            if (Test-Path $restoreTempDir) { Remove-Item $restoreTempDir -Recurse -Force }
        }
    })
}

if ($BannerLink) { $BannerLink.Add_MouseLeftButtonDown({ Start-Process "https://www.osmanonurkoc.com" }) }

# =============================================================================
# 7. STARTUP & DWM API HOOKS
# =============================================================================
if ($Window) {
    $Window.Add_SourceInitialized({
        try {
            $InteropHelper = New-Object System.Windows.Interop.WindowInteropHelper($Window)
            $Hwnd = $InteropHelper.Handle

            if ($CurrentTheme -eq "Dark") {
                $Val = 1
                [void][Win32Tools]::DwmSetWindowAttribute($Hwnd, 20, [ref]$Val, 4)
            }
            $CornerVal = 2
            [void][Win32Tools]::DwmSetWindowAttribute($Hwnd, 33, [ref]$CornerVal, 4)
        } catch { }
    })

    $Window.Add_Loaded({
        if ($IconBitmap) {
            try {
                $InteropHelper = New-Object System.Windows.Interop.WindowInteropHelper($Window)
                $Hwnd = $InteropHelper.Handle
                $IconBytes = [Convert]::FromBase64String($AppIconBase64)
                $script:HiconMemStream = New-Object System.IO.MemoryStream(,$IconBytes)
                $Bitmap = [System.Drawing.Bitmap]::FromStream($script:HiconMemStream)
                $Hicon = $Bitmap.GetHicon()

                [void][Win32Tools]::SendMessage($Hwnd, 0x0080, [IntPtr]0, $Hicon)
                [void][Win32Tools]::SendMessage($Hwnd, 0x0080, [IntPtr]1, $Hicon)
            } catch { }
        }
    })

    [void]$Window.ShowDialog()
}
[System.Environment]::Exit(0)
