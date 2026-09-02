Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
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

# 1. Ask for confirmation using a nice WPF warning popup
$confirmXML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Uninstall HRM Widget" Height="170" Width="360"
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
            
            <TextBlock Grid.Row="0" Text="UNINSTALL HRM WIDGET" Foreground="#FF5E6E" FontSize="11.5" FontWeight="Bold" HorizontalAlignment="Center"/>
            
            <TextBlock Grid.Row="1" Text="Are you sure you want to completely uninstall HRM Live Widget and all its saved data from this computer?" 
                       Foreground="#D1D1D6" FontSize="11" TextWrapping="Wrap" Margin="0,10,0,10" VerticalAlignment="Center" TextAlignment="Center"/>
            
            <StackPanel Orientation="Horizontal" Grid.Row="2" HorizontalAlignment="Right" Margin="0,5,0,0">
                <Button Name="NoBtn" Content="Cancel" Width="80" Height="26" Margin="0,0,8,0"
                        Background="#2A2A34" Foreground="White" BorderBrush="#383846" BorderThickness="1" Cursor="Hand" FontSize="10.5" FontWeight="SemiBold">
                    <Button.Resources>
                        <Style TargetType="Border">
                            <Setter Property="CornerRadius" Value="8"/>
                        </Style>
                    </Button.Resources>
                </Button>
                <Button Name="YesBtn" Content="Uninstall" Width="95" Height="26"
                        Background="#FF4757" Foreground="White" BorderBrush="#FF4757" BorderThickness="1" Cursor="Hand" FontSize="10.5" FontWeight="Bold">
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

$confirmed = $false
try {
    $reader = New-Object System.Xml.XmlTextReader([System.IO.StringReader]::new($confirmXML))
    $win = [System.Windows.Markup.XamlReader]::Load($reader)
    $win.Add_SourceInitialized({
        try {
            $hlp = New-Object System.Windows.Interop.WindowInteropHelper($win)
            [GlassHelper]::EnableBlur($hlp.Handle)
        } catch {}
    })
    $win.Add_MouseLeftButtonDown({ try { $win.DragMove() } catch {} })
    $yesBtn = $win.FindName("YesBtn")
    $noBtn = $win.FindName("NoBtn")
    
    $yesBtn.Add_Click({
        $script:confirmed = $true
        $win.Close()
    })
    $noBtn.Add_Click({
        $win.Close()
    })
    
    $null = $win.ShowDialog()
} catch {
    $confirmed = $true
}

if (-not $confirmed) {
    Exit
}

# 2. Perform Immediate Cleanup of processes, shortcuts, and registry keys
try {
    Get-Process -Name "HRM_Widget" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
} catch {}

# Registry Cleanup
try {
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "HRM_Widget" -ErrorAction SilentlyContinue
} catch {}
try {
    Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\HRM_Widget" -Recurse -Force -ErrorAction SilentlyContinue
} catch {}

# Shortcuts Cleanup
try {
    $startupFolder = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\Windows\Start Menu\Programs\Startup")
    $startupShortcut = [System.IO.Path]::Combine($startupFolder, "HRM_Widget.lnk")
    if (Test-Path $startupShortcut) { Remove-Item $startupShortcut -Force -ErrorAction SilentlyContinue }
    
    $desktopFolder = [Environment]::GetFolderPath("Desktop")
    $desktopShortcut = [System.IO.Path]::Combine($desktopFolder, "HRM Live Widget.lnk")
    if (Test-Path $desktopShortcut) { Remove-Item $desktopShortcut -Force -ErrorAction SilentlyContinue }

    $startMenuPrograms = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\Windows\Start Menu\Programs\HRM Widget")
    if (Test-Path $startMenuPrograms) { Remove-Item $startMenuPrograms -Recurse -Force -ErrorAction SilentlyContinue }
} catch {}

# 3. Create Self-Deleting Temp Script to Remove Folders after Uninstall.exe Exits
$tempBatch = Join-Path $env:TEMP "hrm_uninstall_cleanup.bat"
$localApp = Join-Path $env:LOCALAPPDATA "HRM_Widget"

$batchLines = @(
    "@echo off",
    ":LOOP",
    "timeout /t 1 /nobreak > nul",
    "taskkill /f /im HRM_Widget.exe > nul 2>&1",
    "taskkill /f /im Uninstall.exe > nul 2>&1",
    "if exist `"C:\HRM_Widget`" (",
    "    rd /s /q `"C:\HRM_Widget`" > nul 2>&1",
    ")",
    "if exist `"$localApp`" (",
    "    rd /s /q `"$localApp`" > nul 2>&1",
    ")",
    "if exist `"C:\HRM_Widget`" (",
    "    goto LOOP",
    ")",
    "(goto) 2>nul & del `"%~f0`" & exit"
)

$batchLines -join "`r`n" | Out-File $tempBatch -Encoding ascii

# 4. Show Done Notification
$doneXML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Uninstallation Complete" Height="150" Width="340"
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
            
            <TextBlock Grid.Row="0" Text="UNINSTALLATION COMPLETE" Foreground="#2ED573" FontSize="11" FontWeight="Bold" HorizontalAlignment="Center"/>
            
            <TextBlock Grid.Row="1" Text="HRM Live Widget has been completely removed from your computer." 
                       Foreground="#D1D1D6" FontSize="11" TextWrapping="Wrap" Margin="0,10,0,10" VerticalAlignment="Center" TextAlignment="Center"/>
            
            <Button Name="OkBtn" Content="OK" Width="80" Height="26" Grid.Row="2" HorizontalAlignment="Center"
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
    $reader = New-Object System.Xml.XmlTextReader([System.IO.StringReader]::new($doneXML))
    $doneWin = [System.Windows.Markup.XamlReader]::Load($reader)
    $doneWin.Add_SourceInitialized({
        try {
            $hlp = New-Object System.Windows.Interop.WindowInteropHelper($doneWin)
            [GlassHelper]::EnableBlur($hlp.Handle)
        } catch {}
    })
    $doneWin.Add_MouseLeftButtonDown({ try { $doneWin.DragMove() } catch {} })
    $okBtn = $doneWin.FindName("OkBtn")
    $okBtn.Add_Click({
        $doneWin.Close()
    })
    $null = $doneWin.ShowDialog()
} catch {}

# Launch cleanup batch in hidden window and exit
Start-Process $tempBatch -WindowStyle Hidden
Exit
