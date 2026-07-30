Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

# P/Invoke Helper for native DWM window frosted blur (Liquid Glass)
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class GlassHelper {
    [DllImport("user32.dll")]
    public static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);

    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int attrSize);

    [DllImport("gdi32.dll")]
    public static extern IntPtr CreateRoundRectRgn(int nLeftRect, int nTopRect, int nRightRect, int nBottomRect, int nWidthEllipse, int nHeightEllipse);

    [DllImport("user32.dll")]
    public static extern int SetWindowRgn(IntPtr hWnd, IntPtr hRgn, bool bRedraw);

    [StructLayout(LayoutKind.Sequential)]
    public struct WindowCompositionAttributeData {
        public int Attribute;
        public IntPtr Data;
        public int SizeOfData;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct AccentPolicy {
        public int AccentState;
        public int AccentFlags;
        public int GradientColor;
        public int AnimationId;
    }

    public static void ApplyRoundedWindow(IntPtr hwnd, string theme) {
        try {
            int cornerPref = 1; // DWMWCP_DONOTROUND
            DwmSetWindowAttribute(hwnd, 33, ref cornerPref, sizeof(int));
        } catch {}

        try {
            SetWindowRgn(hwnd, IntPtr.Zero, true);
        } catch {}

        try {
            AccentPolicy accent = new AccentPolicy();
            accent.AccentState = (theme == "clear") ? 1 : 3;
            accent.GradientColor = (theme == "clear") ? 0x01000000 : 0;
            accent.AccentFlags = 0;
            accent.AnimationId = 0;

            int accentStructSize = Marshal.SizeOf(accent);
            IntPtr accentPtr = Marshal.AllocHGlobal(accentStructSize);
            Marshal.StructureToPtr(accent, accentPtr, false);

            WindowCompositionAttributeData data = new WindowCompositionAttributeData();
            data.Attribute = 19;
            data.SizeOfData = accentStructSize;
            data.Data = accentPtr;

            SetWindowCompositionAttribute(hwnd, ref data);
            Marshal.FreeHGlobal(accentPtr);
        } catch {}
    }

    public static void EnableBlur(IntPtr hwnd) {
        ApplyRoundedWindow(hwnd, "frosted");
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
    <Border CornerRadius="22" BorderThickness="1.2" BorderBrush="#50FFFFFF">
        <Border.Background>
            <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                <GradientStop Color="#2CFFFFFF" Offset="0.0"/>
                <GradientStop Color="#06FFFFFF" Offset="0.4"/>
                <GradientStop Color="#15FFFFFF" Offset="1.0"/>
            </LinearGradientBrush>
        </Border.Background>
        <Border.Effect>
            <DropShadowEffect BlurRadius="25" ShadowDepth="0" Color="#FFFFFF" Opacity="0.12"/>
        </Border.Effect>
        <Grid Margin="15">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <TextBlock Grid.Row="0" Text="UNINSTALL HRM WIDGET" Foreground="#FFFF5E6E" FontSize="11" FontWeight="Bold" HorizontalAlignment="Center"/>
            
            <TextBlock Grid.Row="1" Text="Are you sure you want to completely uninstall HRM Live Widget and all its settings from this computer?" 
                       Foreground="White" FontSize="11" TextWrapping="Wrap" Margin="0,5,0,5" VerticalAlignment="Center"/>
            
            <StackPanel Orientation="Horizontal" Grid.Row="2" HorizontalAlignment="Right" Margin="0,5,0,0">
                <Button Name="NoBtn" Content="No, Keep It" Width="95" Height="22" Margin="0,0,8,0"
                        Background="#22FFFFFF" Foreground="White" BorderBrush="#3FFFFFFF" BorderThickness="1" Cursor="Hand" FontSize="10" FontWeight="SemiBold">
                    <Button.Resources>
                        <Style TargetType="Border">
                            <Setter Property="CornerRadius" Value="10"/>
                        </Style>
                    </Button.Resources>
                </Button>
                <Button Name="YesBtn" Content="Yes, Uninstall" Width="95" Height="22"
                        Background="#CCFF4757" Foreground="White" BorderBrush="#3FFFFFFF" BorderThickness="1" Cursor="Hand" FontSize="10" FontWeight="Bold">
                    <Button.Resources>
                        <Style TargetType="Border">
                            <Setter Property="CornerRadius" Value="10"/>
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
del /f /q "$shortcutPath" > nul 2>&1
rmdir /s /q "C:\HRM_Widget" > nul 2>&1
rmdir /s /q "$env:LOCALAPPDATA\HRM_Widget" > nul 2>&1
(goto) 2>nul & del "%~f0" & exit
"@

$batchContent | Out-File $tempBatch -Encoding ascii

# 3. Launch cleanup batch and exit
Start-Process $tempBatch -WindowStyle Hidden
Exit
