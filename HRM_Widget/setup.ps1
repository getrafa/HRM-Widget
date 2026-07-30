Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName System.Drawing

# 1. Beautiful Welcome Dialog
$welcomeXML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="HRM Widget Installer" Height="190" Width="340"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="True" WindowStartupLocation="CenterScreen">
    <Border CornerRadius="16" BorderThickness="1.5" BorderBrush="#4400d2ff" Background="#F2080D18">
        <Border.Effect>
            <DropShadowEffect BlurRadius="20" ShadowDepth="0" Color="#00d2ff" Opacity="0.5"/>
        </Border.Effect>
        <Grid Margin="15">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <TextBlock Grid.Row="0" Text="HRM WIDGET INSTALLER" Foreground="#FF00D2FF" FontSize="11" FontWeight="Bold"/>
            
            <TextBlock Grid.Row="1" Text="This installer will set up the HRM Live Widget on your computer. During the installation, you will be prompted to enter your HRM API Token." 
                       Foreground="White" FontSize="11" TextWrapping="Wrap" Margin="0,10,0,10" VerticalAlignment="Center"/>
            
            <StackPanel Orientation="Horizontal" Grid.Row="2" HorizontalAlignment="Right">
                <Button Name="CancelBtn" Content="Cancel" Width="80" Height="24" Margin="0,0,8,0"
                        Background="#121c30" Foreground="White" BorderBrush="#FFFF4757" BorderThickness="1" Cursor="Hand" FontSize="10.5" FontWeight="SemiBold"/>
                <Button Name="StartBtn" Content="Start Setup" Width="100" Height="24"
                        Background="#FF2ED573" Foreground="White" BorderBrush="Transparent" Cursor="Hand" FontSize="10.5" FontWeight="Bold"/>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@

try {
    $reader = New-Object System.Xml.XmlTextReader([System.IO.StringReader]::new($welcomeXML))
    $welcomeWin = [System.Windows.Markup.XamlReader]::Load($reader)
    $startBtn = $welcomeWin.FindName("StartBtn")
    $cancelBtn = $welcomeWin.FindName("CancelBtn")
    
    $startSetup = $false
    $startBtn.Add_Click({
        $script:startSetup = $true
        $welcomeWin.Close()
    })
    $cancelBtn.Add_Click({
        $welcomeWin.Close()
    })
    
    $null = $welcomeWin.ShowDialog()
    
    if (-not $startSetup) {
        Exit
    }
} catch {
    Write-Host "Starting HRM Widget Setup..."
}

# 2. API Token Input Dialog
$promptXML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="HRM Token Setup" Height="150" Width="330"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="True" WindowStartupLocation="CenterScreen">
    <Border CornerRadius="16" BorderThickness="1.5" BorderBrush="#4400d2ff" Background="#F2080D18">
        <Border.Effect>
            <DropShadowEffect BlurRadius="20" ShadowDepth="0" Color="#00d2ff" Opacity="0.5"/>
        </Border.Effect>
        <Grid Margin="15">
            <Grid.RowDefinitions>
                <Grid.RowDefinition Height="Auto"/>
                <Grid.RowDefinition Height="*"/>
                <Grid.RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <TextBlock Grid.Row="0" Text="ENTER YOUR HRM API TOKEN" Foreground="#FF00D2FF" FontSize="10" FontWeight="Bold"/>
            
            <TextBox Name="TokenBox" Grid.Row="1" Height="24" Width="290" VerticalAlignment="Center" HorizontalAlignment="Center"
                     Background="#121c30" Foreground="White" BorderBrush="#4400d2ff" BorderThickness="1" Padding="4,3,4,3" FontSize="10.5"/>
            
            <StackPanel Orientation="Horizontal" Grid.Row="2" HorizontalAlignment="Right" Margin="0,5,0,0">
                <Button Name="CancelBtn" Content="Cancel" Width="70" Height="22" Margin="0,0,8,0"
                        Background="#121c30" Foreground="White" BorderBrush="#FFFF4757" BorderThickness="1" Cursor="Hand" FontSize="10" FontWeight="SemiBold"/>
                <Button Name="SaveBtn" Content="Save Token" Width="90" Height="22"
                        Background="#FF2ED573" Foreground="White" BorderBrush="Transparent" Cursor="Hand" FontSize="10" FontWeight="Bold"/>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@

$apiToken = ""
try {
    $reader = New-Object System.Xml.XmlTextReader([System.IO.StringReader]::new($promptXML))
    $promptWin = [System.Windows.Markup.XamlReader]::Load($reader)
    $tokenBox = $promptWin.FindName("TokenBox")
    $saveBtn = $promptWin.FindName("SaveBtn")
    $cancelBtn = $promptWin.FindName("CancelBtn")
    
    $promptWin.Add_Loaded({
        $tokenBox.Focus()
    })
    
    $saveBtn.Add_Click({
        if (-not [string]::IsNullOrWhiteSpace($tokenBox.Text)) {
            $script:apiToken = $tokenBox.Text.Trim()
            $promptWin.Close()
        }
    })
    $cancelBtn.Add_Click({
        $promptWin.Close()
    })
    $null = $promptWin.ShowDialog()
} catch {}

if ([string]::IsNullOrEmpty($apiToken)) {
    # If no token, ask in console as fallback
    Write-Host "Please enter your HRM API Token:" -ForegroundColor Cyan
    $apiToken = Read-Host
    if ([string]::IsNullOrWhiteSpace($apiToken)) {
        Write-Host "Setup cancelled. API Token is required." -ForegroundColor Red
        Start-Sleep -Seconds 3
        Exit
    }
}

# 3. Create Installation Directory
$installDir = "C:\HRM_Widget"
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# 4. Copy HRM_Widget.exe
$currentDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if ([string]::IsNullOrEmpty($currentDir)) { $currentDir = Get-Location }
$exeSource = Join-Path $currentDir "HRM_Widget.exe"

if (Test-Path $exeSource) {
    Copy-Item $exeSource -Destination $installDir -Force
    # Copy uninstaller files
    $unbat = Join-Path $currentDir "Uninstall.bat"
    $unps1 = Join-Path $currentDir "uninstall.ps1"
    if (Test-Path $unbat) { Copy-Item $unbat -Destination $installDir -Force }
    if (Test-Path $unps1) { Copy-Item $unps1 -Destination $installDir -Force }
} else {
    Write-Error "Could not find HRM_Widget.exe in installation files!"
    Start-Sleep -Seconds 5
    Exit
}

# 5. Create config.json with target settings and the User's API Token
$configPath = Join-Path $installDir "config.json"
$configObject = [PSCustomObject]@{
    IdleOpacity = 0.65
    HoverOpacity = 1.0
    TargetHours = 8.0
    ApiToken = $apiToken
}
$configObject | ConvertTo-Json | Out-File $configPath -Encoding utf8

# 6. Create Start Menu Startup Shortcut
$startupFolder = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\Windows\Start Menu\Programs\Startup")
$shortcutPath = [System.IO.Path]::Combine($startupFolder, "HRM_Widget.lnk")
try {
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "C:\HRM_Widget\HRM_Widget.exe"
    $shortcut.WorkingDirectory = "C:\HRM_Widget"
    $shortcut.Description = "HRM Attendance Widget"
    $shortcut.IconLocation = "C:\HRM_Widget\HRM_Widget.exe,0"
    $shortcut.Save()
} catch {
    Write-Host "Warning: Could not create startup shortcut: $_" -ForegroundColor Yellow
}

# 7. Start the Widget immediately!
try {
    Start-Process "C:\HRM_Widget\HRM_Widget.exe" -WorkingDirectory "C:\HRM_Widget"
} catch {
    Write-Host "Warning: Could not launch widget: $_" -ForegroundColor Yellow
}

# 8. Success Info Popup
$successXML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Setup Complete" Height="140" Width="300"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="True" WindowStartupLocation="CenterScreen">
    <Border CornerRadius="16" BorderThickness="1.5" BorderBrush="#FF2ED573" Background="#F2080D18">
        <Border.Effect>
            <DropShadowEffect BlurRadius="20" ShadowDepth="0" Color="#2ED573" Opacity="0.5"/>
        </Border.Effect>
        <Grid Margin="15">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <TextBlock Grid.Row="0" Text="INSTALLATION SUCCESSFUL" Foreground="#FF2ED573" FontSize="10" FontWeight="Bold"/>
            
            <TextBlock Grid.Row="1" Text="HRM Widget has been installed to C:\HRM_Widget and added to your system startup." 
                       Foreground="White" FontSize="11" TextWrapping="Wrap" Margin="0,5,0,5" VerticalAlignment="Center"/>
            
            <Button Name="FinishBtn" Content="Finish" Width="80" Height="22" Grid.Row="2" HorizontalAlignment="Right"
                    Background="#121c30" Foreground="White" BorderBrush="#FF2ED573" BorderThickness="1" Cursor="Hand" FontSize="10" FontWeight="Bold"/>
        </Grid>
    </Border>
</Window>
"@

try {
    $reader = New-Object System.Xml.XmlTextReader([System.IO.StringReader]::new($successXML))
    $successWin = [System.Windows.Markup.XamlReader]::Load($reader)
    $finishBtn = $successWin.FindName("FinishBtn")
    $finishBtn.Add_Click({
        $successWin.Close()
    })
    $null = $successWin.ShowDialog()
} catch {
    Write-Host "Installation completed successfully! Widget is running." -ForegroundColor Green
    Start-Sleep -Seconds 3
}
