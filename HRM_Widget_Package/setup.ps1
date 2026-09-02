Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName WindowsBase

# P/Invoke Helper for native DWM window frosted blur
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class GlassHelper {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int attrSize);

    [DllImport("user32.dll")]
    public static extern int SetWindowRgn(IntPtr hWnd, IntPtr hRgn, bool bRedraw);

    public static void ApplyRoundedWindow(IntPtr hwnd, string theme) {
        try {
            int cornerPref = 1; // DWMWCP_DONOTROUND
            DwmSetWindowAttribute(hwnd, 33, ref cornerPref, sizeof(int));
        } catch {}

        try {
            SetWindowRgn(hwnd, IntPtr.Zero, true);
        } catch {}
    }

    public static void EnableBlur(IntPtr hwnd) {
        ApplyRoundedWindow(hwnd, "solid");
    }
}
"@ -ErrorAction SilentlyContinue

# Determine Source Directory robustly
$sourceDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($sourceDir)) {
    $sourceDir = [System.AppDomain]::CurrentDomain.BaseDirectory
}
if ([string]::IsNullOrEmpty($sourceDir)) {
    try {
        $sourceDir = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
    } catch {}
}
if ([string]::IsNullOrEmpty($sourceDir)) {
    $sourceDir = Get-Location
}

# Check existing token if present
$existingToken = ""
$localAppFolder = Join-Path $env:LOCALAPPDATA "HRM_Widget"
$configPath = Join-Path $localAppFolder "config.json"
if (Test-Path $configPath) {
    try {
        $json = Get-Content $configPath -Raw -Encoding utf8 | ConvertFrom-Json
        if ($json.ApiToken) {
            $existingToken = $json.ApiToken
        }
    } catch {}
}

# 1. Beautiful Welcome Dialog
$welcomeXML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="HRM Widget Setup" Height="200" Width="360"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="True" WindowStartupLocation="CenterScreen">
    <Border CornerRadius="16" BorderThickness="1" BorderBrush="#2E2E38" Background="#18181C">
        <Border.Effect>
            <DropShadowEffect BlurRadius="24" ShadowDepth="4" Color="#000000" Opacity="0.5"/>
        </Border.Effect>
        <Grid Margin="18">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Center">
                <TextBlock Text="⚡ " FontSize="13" Foreground="#2ED573"/>
                <TextBlock Text="HRM LIVE WIDGET SETUP" Foreground="White" FontSize="11.5" FontWeight="Bold"/>
            </StackPanel>
            
            <TextBlock Grid.Row="1" Text="This wizard will install HRM Live Widget on your computer and configure automatic startup on boot." 
                       Foreground="#D1D1D6" FontSize="11" TextWrapping="Wrap" Margin="0,12,0,12" VerticalAlignment="Center" TextAlignment="Center"/>
            
            <StackPanel Orientation="Horizontal" Grid.Row="2" HorizontalAlignment="Right">
                <Button Name="CancelBtn" Content="Cancel" Width="80" Height="26" Margin="0,0,8,0"
                        Background="#2A2A34" Foreground="White" BorderBrush="#383846" BorderThickness="1" Cursor="Hand" FontSize="10.5" FontWeight="SemiBold">
                    <Button.Resources>
                        <Style TargetType="Border">
                            <Setter Property="CornerRadius" Value="8"/>
                        </Style>
                    </Button.Resources>
                </Button>
                <Button Name="StartBtn" Content="Next >" Width="90" Height="26"
                        Background="#2ED573" Foreground="White" BorderBrush="#2ED573" BorderThickness="1" Cursor="Hand" FontSize="10.5" FontWeight="Bold">
                    <Button.Resources>
                        <Style TargetType="Border">
                            <Setter Property="CornerRadius" Value="8"/>
                        </Style>
                    </Button.Resources>
                </Button>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@

$startSetup = $false
try {
    $reader = New-Object System.Xml.XmlTextReader([System.IO.StringReader]::new($welcomeXML))
    $welcomeWin = [System.Windows.Markup.XamlReader]::Load($reader)
    $welcomeWin.Add_SourceInitialized({
        try {
            $hlp = New-Object System.Windows.Interop.WindowInteropHelper($welcomeWin)
            [GlassHelper]::EnableBlur($hlp.Handle)
        } catch {}
    })
    $welcomeWin.Add_MouseLeftButtonDown({ try { $welcomeWin.DragMove() } catch {} })
    $startBtn = $welcomeWin.FindName("StartBtn")
    $cancelBtn = $welcomeWin.FindName("CancelBtn")
    
    $startBtn.Add_Click({
        $script:startSetup = $true
        $welcomeWin.Close()
    })
    $cancelBtn.Add_Click({
        $welcomeWin.Close()
    })
    
    $null = $welcomeWin.ShowDialog()
} catch {
    $startSetup = $true
}

if (-not $startSetup) {
    Exit
}

# 2. API Token Input Dialog
$tokenXML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="HRM Token Setup" Height="170" Width="360"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="True" WindowStartupLocation="CenterScreen">
    <Border CornerRadius="16" BorderThickness="1" BorderBrush="#2E2E38" Background="#18181C">
        <Border.Effect>
            <DropShadowEffect BlurRadius="24" ShadowDepth="4" Color="#000000" Opacity="0.5"/>
        </Border.Effect>
        <Grid Margin="18">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <TextBlock Grid.Row="0" Text="ENTER YOUR HRM API TOKEN" Foreground="White" FontSize="11" FontWeight="Bold" HorizontalAlignment="Center"/>
            
            <StackPanel Grid.Row="1" VerticalAlignment="Center" Margin="0,10,0,10">
                <TextBox Name="TokenBox" Height="28" Width="320"
                         Background="#24242C" Foreground="White" BorderBrush="#3A3A46" BorderThickness="1" Padding="8,5,8,5" FontSize="11" CaretBrush="White">
                    <TextBox.Resources>
                        <Style TargetType="Border">
                            <Setter Property="CornerRadius" Value="6"/>
                        </Style>
                    </TextBox.Resources>
                </TextBox>
            </StackPanel>
            
            <StackPanel Orientation="Horizontal" Grid.Row="2" HorizontalAlignment="Right">
                <Button Name="CancelBtn" Content="Cancel" Width="80" Height="26" Margin="0,0,8,0"
                        Background="#2A2A34" Foreground="White" BorderBrush="#383846" BorderThickness="1" Cursor="Hand" FontSize="10.5" FontWeight="SemiBold">
                    <Button.Resources>
                        <Style TargetType="Border">
                            <Setter Property="CornerRadius" Value="8"/>
                        </Style>
                    </Button.Resources>
                </Button>
                <Button Name="SaveBtn" Content="Install Now" Width="100" Height="26"
                        Background="#2ED573" Foreground="White" BorderBrush="#2ED573" BorderThickness="1" Cursor="Hand" FontSize="10.5" FontWeight="Bold">
                    <Button.Resources>
                        <Style TargetType="Border">
                            <Setter Property="CornerRadius" Value="8"/>
                        </Style>
                    </Button.Resources>
                </Button>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@

$apiToken = $existingToken
try {
    $reader = New-Object System.Xml.XmlTextReader([System.IO.StringReader]::new($tokenXML))
    $promptWin = [System.Windows.Markup.XamlReader]::Load($reader)
    $promptWin.Add_SourceInitialized({
        try {
            $hlp = New-Object System.Windows.Interop.WindowInteropHelper($promptWin)
            [GlassHelper]::EnableBlur($hlp.Handle)
        } catch {}
    })
    $promptWin.Add_MouseLeftButtonDown({ try { $promptWin.DragMove() } catch {} })
    $tokenBox = $promptWin.FindName("TokenBox")
    $saveBtn = $promptWin.FindName("SaveBtn")
    $cancelBtn = $promptWin.FindName("CancelBtn")
    
    if (-not [string]::IsNullOrEmpty($existingToken)) {
        $tokenBox.Text = $existingToken
    }
    
    $promptWin.Add_Loaded({
        $tokenBox.Focus()
        if (-not [string]::IsNullOrEmpty($tokenBox.Text)) {
            $tokenBox.SelectAll()
        }
    })
    
    $saveBtn.Add_Click({
        if (-not [string]::IsNullOrWhiteSpace($tokenBox.Text)) {
            $script:apiToken = $tokenBox.Text.Trim()
            $promptWin.Close()
        }
    })
    $cancelBtn.Add_Click({
        $promptWin.Close()
        Exit
    })
    $null = $promptWin.ShowDialog()
} catch {}

if ([string]::IsNullOrWhiteSpace($apiToken)) {
    Exit
}

# 3. Create Installation Directory
$installDir = "C:\HRM_Widget"
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# Gracefully terminate any running instance of the widget
try {
    Get-Process -Name "HRM_Widget" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
} catch {}

# 4. Copy Application & Uninstaller Files
$exeSource = Join-Path $sourceDir "HRM_Widget.exe"
if (Test-Path $exeSource) {
    Copy-Item $exeSource -Destination $installDir -Force
} else {
    # If not found in current directory, check parent
    $parentExe = Join-Path (Split-Path -Parent $sourceDir) "HRM_Widget.exe"
    if (Test-Path $parentExe) {
        Copy-Item $parentExe -Destination $installDir -Force
    }
}

# Copy Uninstaller and assets
$uninstallerSource = Join-Path $sourceDir "Uninstall.exe"
if (Test-Path $uninstallerSource) {
    Copy-Item $uninstallerSource -Destination $installDir -Force
}

$filesToCopy = @("Uninstall.bat", "uninstall.ps1", "app.ico", "batman_bg.png", "spiderman_bg.png", "eren_bg.png", "goku_bg.png", "natsu_bg.png")
foreach ($f in $filesToCopy) {
    $src = Join-Path $sourceDir $f
    if (Test-Path $src) {
        Copy-Item $src -Destination $installDir -Force
    }
}

# 5. Create/Update config.json in user LocalAppData folder
if (-not (Test-Path $localAppFolder)) {
    New-Item -ItemType Directory -Path $localAppFolder -Force | Out-Null
}
$configObject = [PSCustomObject]@{
    IdleOpacity = 0.65
    HoverOpacity = 1.0
    TargetHours = 8.0
    ApiToken = $apiToken
    Theme = "batman"
    Scale = 1.0
}
# Preserve existing theme/scale if present
if (Test-Path $configPath) {
    try {
        $oldConfig = Get-Content $configPath -Raw -Encoding utf8 | ConvertFrom-Json
        if ($oldConfig.Theme) { $configObject.Theme = $oldConfig.Theme }
        if ($oldConfig.Scale) { $configObject.Scale = $oldConfig.Scale }
        if ($oldConfig.TargetHours) { $configObject.TargetHours = $oldConfig.TargetHours }
    } catch {}
}
$configObject | ConvertTo-Json | Out-File $configPath -Encoding utf8

# 6. Create Registry Auto-Start & Windows Registry Uninstall Entry
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "HRM_Widget" -Value "C:\HRM_Widget\HRM_Widget.exe" -Force
} catch {}

try {
    $uninstallRegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\HRM_Widget"
    if (-not (Test-Path $uninstallRegPath)) {
        New-Item -Path $uninstallRegPath -Force | Out-Null
    }
    Set-ItemProperty -Path $uninstallRegPath -Name "DisplayName" -Value "HRM Live Widget" -Force
    Set-ItemProperty -Path $uninstallRegPath -Name "DisplayVersion" -Value "1.0.0" -Force
    Set-ItemProperty -Path $uninstallRegPath -Name "Publisher" -Value "Acodez" -Force
    Set-ItemProperty -Path $uninstallRegPath -Name "InstallLocation" -Value "C:\HRM_Widget" -Force
    Set-ItemProperty -Path $uninstallRegPath -Name "UninstallString" -Value "C:\HRM_Widget\Uninstall.exe" -Force
    Set-ItemProperty -Path $uninstallRegPath -Name "DisplayIcon" -Value "C:\HRM_Widget\HRM_Widget.exe,0" -Force
    Set-ItemProperty -Path $uninstallRegPath -Name "NoModify" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $uninstallRegPath -Name "NoRepair" -Value 1 -Type DWord -Force
} catch {}

# 7. Create Start Menu & Startup Shortcuts
try {
    $wshShell = New-Object -ComObject WScript.Shell
    
    # Startup Shortcut
    $startupFolder = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\Windows\Start Menu\Programs\Startup")
    $startupShortcutPath = [System.IO.Path]::Combine($startupFolder, "HRM_Widget.lnk")
    $startupShortcut = $wshShell.CreateShortcut($startupShortcutPath)
    $startupShortcut.TargetPath = "C:\HRM_Widget\HRM_Widget.exe"
    $startupShortcut.WorkingDirectory = "C:\HRM_Widget"
    $startupShortcut.Description = "HRM Attendance Widget"
    $startupShortcut.IconLocation = "C:\HRM_Widget\HRM_Widget.exe,0"
    $startupShortcut.Save()
    
    # Start Menu Programs Folder
    $startMenuPrograms = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\Windows\Start Menu\Programs\HRM Widget")
    if (-not (Test-Path $startMenuPrograms)) {
        New-Item -ItemType Directory -Path $startMenuPrograms -Force | Out-Null
    }
    
    # Main App Shortcut in Programs
    $appShortcutPath = [System.IO.Path]::Combine($startMenuPrograms, "HRM Live Widget.lnk")
    $appShortcut = $wshShell.CreateShortcut($appShortcutPath)
    $appShortcut.TargetPath = "C:\HRM_Widget\HRM_Widget.exe"
    $appShortcut.WorkingDirectory = "C:\HRM_Widget"
    $appShortcut.Description = "HRM Live Widget"
    $appShortcut.IconLocation = "C:\HRM_Widget\HRM_Widget.exe,0"
    $appShortcut.Save()
    
    # Uninstall Shortcut in Programs
    $unShortcutPath = [System.IO.Path]::Combine($startMenuPrograms, "Uninstall HRM Widget.lnk")
    $unShortcut = $wshShell.CreateShortcut($unShortcutPath)
    $unShortcut.TargetPath = "C:\HRM_Widget\Uninstall.exe"
    $unShortcut.WorkingDirectory = "C:\HRM_Widget"
    $unShortcut.Description = "Uninstall HRM Live Widget"
    $unShortcut.IconLocation = "C:\HRM_Widget\Uninstall.exe,0"
    $unShortcut.Save()
    
    # Desktop Shortcut
    $desktopFolder = [Environment]::GetFolderPath("Desktop")
    $desktopShortcutPath = [System.IO.Path]::Combine($desktopFolder, "HRM Live Widget.lnk")
    $desktopShortcut = $wshShell.CreateShortcut($desktopShortcutPath)
    $desktopShortcut.TargetPath = "C:\HRM_Widget\HRM_Widget.exe"
    $desktopShortcut.WorkingDirectory = "C:\HRM_Widget"
    $desktopShortcut.Description = "HRM Live Widget"
    $desktopShortcut.IconLocation = "C:\HRM_Widget\HRM_Widget.exe,0"
    $desktopShortcut.Save()
} catch {}

# 8. Start the Widget immediately
try {
    Start-Process "C:\HRM_Widget\HRM_Widget.exe" -WorkingDirectory "C:\HRM_Widget"
} catch {}

# 9. Success Info Dialog
$successXML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Setup Complete" Height="170" Width="360"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="True" WindowStartupLocation="CenterScreen">
    <Border CornerRadius="16" BorderThickness="1" BorderBrush="#2E2E38" Background="#18181C">
        <Border.Effect>
            <DropShadowEffect BlurRadius="24" ShadowDepth="4" Color="#000000" Opacity="0.5"/>
        </Border.Effect>
        <Grid Margin="18">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <TextBlock Grid.Row="0" Text="INSTALLATION SUCCESSFUL" Foreground="#2ED573" FontSize="11" FontWeight="Bold" HorizontalAlignment="Center"/>
            
            <TextBlock Grid.Row="1" Text="HRM Widget is now running on your desktop and will automatically launch every time your computer starts." 
                       Foreground="#D1D1D6" FontSize="11" TextWrapping="Wrap" Margin="0,10,0,10" VerticalAlignment="Center" TextAlignment="Center"/>
            
            <Button Name="FinishBtn" Content="Finish" Width="90" Height="26" Grid.Row="2" HorizontalAlignment="Center"
                    Background="#2ED573" Foreground="White" BorderBrush="#2ED573" BorderThickness="1" Cursor="Hand" FontSize="10.5" FontWeight="Bold">
                <Button.Resources>
                    <Style TargetType="Border">
                        <Setter Property="CornerRadius" Value="8"/>
                    </Style>
                </Button.Resources>
            </Button>
        </Grid>
    </Border>
</Window>
"@

try {
    $reader = New-Object System.Xml.XmlTextReader([System.IO.StringReader]::new($successXML))
    $successWin = [System.Windows.Markup.XamlReader]::Load($reader)
    $successWin.Add_SourceInitialized({
        try {
            $hlp = New-Object System.Windows.Interop.WindowInteropHelper($successWin)
            [GlassHelper]::EnableBlur($hlp.Handle)
        } catch {}
    })
    $successWin.Add_MouseLeftButtonDown({ try { $successWin.DragMove() } catch {} })
    $finishBtn = $successWin.FindName("FinishBtn")
    $finishBtn.Add_Click({
        $successWin.Close()
    })
    $null = $successWin.ShowDialog()
} catch {}
