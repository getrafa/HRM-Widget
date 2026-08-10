Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

# P/Invoke Helper for native DWM window frosted blur (Liquid Glass)
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
"@

# 1. Ask for confirmation using a nice WPF warning popup
$confirmXML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Uninstall HRM Widget" Height="150" Width="330"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="True" WindowStartupLocation="CenterScreen">
    <Border CornerRadius="16" BorderThickness="1" BorderBrush="#2E2E38" Background="#18181C">
        <Border.Effect>
            <DropShadowEffect BlurRadius="20" ShadowDepth="4" Color="#000000" Opacity="0.4"/>
        </Border.Effect>
        <Grid Margin="15">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <TextBlock Grid.Row="0" Text="UNINSTALL HRM WIDGET" Foreground="#FF5E6E" FontSize="11" FontWeight="Bold" HorizontalAlignment="Center"/>
            
            <TextBlock Grid.Row="1" Text="Are you sure you want to completely uninstall HRM Live Widget and all its settings from this computer?" 
                       Foreground="#D1D1D6" FontSize="11" TextWrapping="Wrap" Margin="0,5,0,5" VerticalAlignment="Center"/>
            
            <StackPanel Orientation="Horizontal" Grid.Row="2" HorizontalAlignment="Right" Margin="0,5,0,0">
                <Button Name="NoBtn" Content="No, Keep It" Width="95" Height="24" Margin="0,0,8,0"
                        Background="#2A2A34" Foreground="White" BorderBrush="#383846" BorderThickness="1" Cursor="Hand" FontSize="10" FontWeight="SemiBold">
                    <Button.Resources>
                        <Style TargetType="Border">
                            <Setter Property="CornerRadius" Value="8"/>
                        </Style>
                    </Button.Resources>
                </Button>
                <Button Name="YesBtn" Content="Yes, Uninstall" Width="95" Height="24"
                        Background="#FF4757" Foreground="White" BorderBrush="#FF4757" BorderThickness="1" Cursor="Hand" FontSize="10" FontWeight="Bold">
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
    Write-Host "Are you sure you want to uninstall HRM Widget? (Y/N):" -ForegroundColor Red
    $ans = Read-Host
    if ($ans -eq "y" -or $ans -eq "Y") {
        $confirmed = $true
    }
}

if (-not $confirmed) {
    Exit
}

# 2. Setup self-deleting batch script in TEMP directory
$tempBatch = Join-Path $env:TEMP "cleanup_hrm.bat"
$startupFolder = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\Windows\Start Menu\Programs\Startup")
$shortcutPath = [System.IO.Path]::Combine($startupFolder, "HRM_Widget.lnk")

$batchContent = @"
@echo off
timeout /t 1 /nobreak > nul
taskkill /f /im HRM_Widget.exe > nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "HRM_Widget" /f > nul 2>&1
del /f /q "$shortcutPath" > nul 2>&1
rmdir /s /q "C:\HRM_Widget" > nul 2>&1
rmdir /s /q "$env:LOCALAPPDATA\HRM_Widget" > nul 2>&1
(goto) 2>nul & del "%~f0" & exit
"@

$batchContent | Out-File $tempBatch -Encoding ascii

# 3. Launch cleanup batch and exit
Start-Process $tempBatch -WindowStyle Hidden
Exit
