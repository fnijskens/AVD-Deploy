<#Author       : Dean Cefola
# Creation Date: 09-15-2019
# Usage        : Windows Virtual Desktop Scripted Install

#********************************************************************************
# Date                         Version      Changes
#------------------------------------------------------------------------
# 09/15/2019                     1.0        Intial Version
# 09/16/2019                     2.0        Add FSLogix installer
# 09/16/2019                     2.1        Add FSLogix Reg Keys 
# 09/16/2019                     2.2        Add Input Parameters 
# 09/16/2019                     2.3        Add TLS 1.2 settings
# 09/17/2019                     3.0        Chang download locations to dynamic
# 09/17/2019                     3.1        Add code to disable IESEC for admins
# 09/20/2019                     3.2        Add code to discover OS (Server / Client)
# 09/20/2019                     4.0        Add code for servers to add RDS Host role
# 10/01/2019                     4.2        Add all FSLogix Profile Container Reg entries for easier management
# 10/07/2019                     4.3        Add FSLogix Office Container Reg entries for easier management
# 10/16/2019                     5.0        Add Windows 7 Support
# 07/20/2020                     6.0        Add AVD Optimize Code from The-Virtual-Desktop-Team
# 10/27/2020                     7.0        Optimize FSLogix settings - Remove Office Profile Settings
# 02/01/2021                     7.1        Add RegKey for Screen Protection
# 05/22/2021                     7.2        Multiple changes to AVD Optimization code (remove winversion, Add EULA, Add Paramater for Optimize All
# 06/30/2021                     7.3        Add RegKey for Azure AD Join
#
#*********************************************************************************
#
#>


##############################
#    AVD Script Parameters   #
##############################
Param (        
    [Parameter(Mandatory=$true)]
        [string]$RegistrationToken          
)


######################
#    AVD Variables   #
######################
$LocalAVDpath            = "c:\temp\AVD\"
$AVDBootURI              = 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH'
$AVDAgentURI             = 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv'
$AVDAgentInstaller       = 'AVD-Agent.msi'
$AVDBootInstaller        = 'AVD-Bootloader.msi'


####################################
#    Test/Create Temp Directory    #
####################################
if((Test-Path c:\temp) -eq $false) {
    Add-Content -LiteralPath C:\New-AVDSessionHost.log "Create C:\temp Directory"
    Write-Host `
        -ForegroundColor Cyan `
        -BackgroundColor Black `
        "creating temp directory"
    New-Item -Path c:\temp -ItemType Directory
}
else {
    Add-Content -LiteralPath C:\New-AVDSessionHost.log "C:\temp Already Exists"
    Write-Host `
        -ForegroundColor Yellow `
        -BackgroundColor Black `
        "temp directory already exists"
}
if((Test-Path $LocalAVDpath) -eq $false) {
    Add-Content -LiteralPath C:\New-AVDSessionHost.log "Create C:\temp\AVD Directory"
    Write-Host `
        -ForegroundColor Cyan `
        -BackgroundColor Black `
        "creating c:\temp\AVD directory"
    New-Item -Path $LocalAVDpath -ItemType Directory
}
else {
    Add-Content -LiteralPath C:\New-AVDSessionHost.log "C:\temp\AVD Already Exists"
    Write-Host `
        -ForegroundColor Yellow `
        -BackgroundColor Black `
        "c:\temp\AVD directory already exists"
}
New-Item -Path c:\ -Name New-AVDSessionHost.log -ItemType File
Add-Content `
-LiteralPath C:\New-AVDSessionHost.log `
"
RegistrationToken = $RegistrationToken
"


#################################
#    Download AVD Componants    #
#################################
Add-Content -LiteralPath C:\New-AVDSessionHost.log "Downloading AVD Boot Loader"
    Invoke-WebRequest -Uri $AVDBootURI -OutFile "$LocalAVDpath$AVDBootInstaller"
Add-Content -LiteralPath C:\New-AVDSessionHost.log "Downloading AVD Agent"
    Invoke-WebRequest -Uri $AVDAgentURI -OutFile "$LocalAVDpath$AVDAgentInstaller"


##############################
#    Prep for AVD Install    #
##############################

##############################
#    OS Specific Settings    #
##############################
$OS = (Get-WmiObject win32_operatingsystem).name
If(($OS) -match 'server') {
    Add-Content -LiteralPath C:\New-AVDSessionHost.log "Windows Server OS Detected"
    write-host -ForegroundColor Cyan -BackgroundColor Black "Windows Server OS Detected"
    If(((Get-WindowsFeature -Name RDS-RD-Server).installstate) -eq 'Installed') {
        "Session Host Role is already installed"
    }
    Else {
        "Installing Session Host Role"
        Install-WindowsFeature `
            -Name RDS-RD-Server `
            -Verbose `
            -LogPath "$LocalAVDpath\RdsServerRoleInstall.txt"
    }
    $AdminsKey = "SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UsersKey = "SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    $BaseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey("LocalMachine","Default")
    $SubKey = $BaseKey.OpenSubkey($AdminsKey,$true)
    $SubKey.SetValue("IsInstalled",0,[Microsoft.Win32.RegistryValueKind]::DWORD)
    $SubKey = $BaseKey.OpenSubKey($UsersKey,$true)
    $SubKey.SetValue("IsInstalled",0,[Microsoft.Win32.RegistryValueKind]::DWORD)    
}
Else {
    Add-Content -LiteralPath C:\New-AVDSessionHost.log "Windows Client OS Detected"
    write-host -ForegroundColor Cyan -BackgroundColor Black "Windows Client OS Detected"
    if(($OS) -match 'Windows 10') {
        write-host `
            -ForegroundColor Yellow `
            -BackgroundColor Black  `
            "Windows 10 detected...skipping to next step"
        Add-Content -LiteralPath C:\New-AVDSessionHost.log "Windows 10 Detected...skipping to next step"     
    }    
}


################################
#    Install AVD Componants    #
################################
Add-Content -LiteralPath C:\New-AVDSessionHost.log "Installing AVD Bootloader"
$bootloader_deploy_status = Start-Process `
    -FilePath "msiexec.exe" `
    -ArgumentList "/i $AVDBootInstaller", `
        "/quiet", `
        "/qn", `
        "/norestart", `
        "/passive", `
        "/l* $LocalAVDpath\AgentBootLoaderInstall.txt" `
    -Wait `
    -Passthru
$sts = $bootloader_deploy_status.ExitCode
Add-Content -LiteralPath C:\New-AVDSessionHost.log "Installing AVD Bootloader Complete"
Write-Output "Installing RDAgentBootLoader on VM Complete. Exit code=$sts`n"
Wait-Event -Timeout 5
Add-Content -LiteralPath C:\New-AVDSessionHost.log "Installing AVD Agent"
Write-Output "Installing RD Infra Agent on VM $AgentInstaller`n"
$agent_deploy_status = Start-Process `
    -FilePath "msiexec.exe" `
    -ArgumentList "/i $AVDAgentInstaller", `
        "/quiet", `
        "/qn", `
        "/norestart", `
        "/passive", `
        "REGISTRATIONTOKEN=$RegistrationToken", "/l* $LocalAVDpath\AgentInstall.txt" `
    -Wait `
    -Passthru
Add-Content -LiteralPath C:\New-AVDSessionHost.log "AVD Agent Install Complete"
Wait-Event -Timeout 5



##########################################
#    Enable Screen Capture Protection    #
##########################################
Add-Content -LiteralPath C:\New-AVDSessionHost.log "Enable Screen Capture Protection"
Push-Location 
Set-Location "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
New-ItemProperty `
    -Path .\ `
    -Name fEnableScreenCaptureProtection `
    -Value "1" `
    -PropertyType DWord `
    -Force
Pop-Location


##############################
#    Enable Azure AD Join    #
##############################
Add-Content -LiteralPath C:\New-AVDSessionHost.log "Enable Azure AD Join"
Push-Location 
Set-Location HKLM:\SOFTWARE\Microsoft
New-Item `
    -Path HKLM:\SOFTWARE\Microsoft `
    -Name RDInfraAgent `
    -Force
New-Item `
    -Path HKLM:\Software\Microsoft\RDInfraAgent `
    -Name AADJPrivate `
    -Force
Pop-Location

##########################
#    Restart Computer    #
##########################
Add-Content -LiteralPath C:\New-AVDSessionHost.log "Process Complete - REBOOT"
Restart-Computer -Force 
