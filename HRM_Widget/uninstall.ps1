Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

# 1. Ask for confirmation using a nice WPF warning popup
$confirmXML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Uninstall HRM Widget" Height="150" Width="330"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="True" WindowStartupLocation="CenterScreen">
    <Border CornerRadius="16" BorderThickness="1.5" BorderBrush="#FFFF4757" Background="#F2080D18">
        <Border.Effect>
            <DropShadowEffect BlurRadius="20" ShadowDepth="0" Color="#FF4757" Opacity="0.5"/>
        </Border.Effect>
        <Grid Margin="15">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <TextBlock Grid.Row="0" Text="UNINSTALL HRM WIDGET" Foreground="#FFFF4757" FontSize="11" FontWeight="Bold"/>
            
            <TextBlock Grid.Row="1" Text="Are you sure you want to completely uninstall HRM Live Widget and all its settings from this computer?" 
                       Foreground="White" FontSize="11" TextWrapping="Wrap" Margin="0,5,0,5" VerticalAlignment="Center"/>
            
            <StackPanel Orientation="Horizontal" Grid.Row="2" HorizontalAlignment="Right" Margin="0,5,0,0">
                <Button Name="NoBtn" Content="No, Keep It" Width="95" Height="22" Margin="0,0,8,0"
                        Background="#121c30" Foreground="White" BorderBrush="#FF2ED573" BorderThickness="1" Cursor="Hand" FontSize="10" FontWeight="SemiBold"/>
                <Button Name="YesBtn" Content="Yes, Uninstall" Width="95" Height="22"
                        Background="#121c30" Foreground="White" BorderBrush="#FFFF4757" BorderThickness="1" Cursor="Hand" FontSize="10" FontWeight="Bold"/>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@

$confirmed = $false
try {
    $reader = New-Object System.Xml.XmlTextReader([System.IO.StringReader]::new($confirmXML))
    $win = [System.Windows.Markup.XamlReader]::Load($reader)
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
(goto) 2>nul & del "%~f0" & exit
"@

$batchContent | Out-File $tempBatch -Encoding ascii

# 3. Launch cleanup batch and exit
Start-Process $tempBatch -WindowStyle Hidden
Exit
