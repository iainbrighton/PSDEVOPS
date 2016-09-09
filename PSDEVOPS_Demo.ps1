
Set-Location -Path '~\Documents\PSDEVOPS'
$configuration = '.\PSDEVOPS.psd1'
$configurationPath = '{0}\PSDEVOPS' -f (Get-LabHostDefault).ConfigurationPath

#region Prep

## Empty the current user modules (different configurations might require different DSC resource versions
Get-ChildItem -Path '~\Documents\PSDEVOPS' -Include *v2.psd1,*.bak -Recurse | Remove-Item -Force
Remove-Item -Path '~\Documents\WindowsPowerShell\Modules' -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path $configurationPath -Recurse -Force;

## Read the configuration document and install/expand the required DSC resources
Import-Module Lability, LabilityBootstrap -Force
Install-LabModule -ConfigurationData $configuration -ModuleType DscResource -Scope CurrentUser -Verbose

## Remove any previous test runs..
Remove-LabConfiguration -ConfigurationData $configuration -Verbose

#endregion Prep

Get-Module -Name Lability -ListAvailable
Find-Module -Name Lability -AllVersions
Import-Module Lability -Force
Get-Command -Module Lability

## Get the host's default values
Get-LabHostDefault

## Backup the current configuration
Export-LabHostConfiguration -Path .\LabilityBackup.bak -Verbose | Invoke-Item;

## Get the virtual machine default values
Get-LabVMDefault


## Review the existing DSC configuration
PSEdit -Filenames .\PSDEVOPS.ps1,.\PSDEVOPS.Original.psd1

## Review the additional Lability metadata
PSEdit -Filenames .\PSDEVOPS.psd1

Invoke-LabResourceDownload -ConfigurationData $configuration -Verbose -DSCResources
Invoke-LabResourceDownload -ConfigurationData $configuration -Verbose -Modules
Invoke-LabResourceDownload -ConfigurationData $configuration -Verbose -Resources

$labCredential = Get-Credential Administrator



## Import the configuration and compile the MOFs
. '.\PSDEVOPS.ps1'
PSDEVOPS -OutputPath $configurationPath -ConfigurationData $configuration -Credential $labCredential


## Start the lab deployment/configuration
Start-LabConfiguration -ConfigurationData $configuration -Path $configurationPath -Credential $labCredential -Verbose -Force

## Start DC1 to ensure that AD is up and running
Start-VM -Name PSDEVOPS-DC1 -Passthru | %{ vmconnect localhost $_.Name }

## Start all the other VMs (DC1 
Start-Lab -ConfigurationData $configuration -Verbose

## Wait for lab deployment/completion, CLIENT1 has a DHCP address so we need resolve it first!
$vmIPs = @('10.200.0.10', '10.200.0.11', (Resolve-DnsName -Name client1.psdevops.local -Server 10.200.0.10).IPAddress)
#$vmIPs = @('10.200.0.10', '10.200.0.11')
.\Get-LabStatus -ComputerName $vmIPs -Credential $labCredential -Verbose;

## Run some tests..
$dc1Session = Get-PSSession | Where-Object ComputerName -eq '10.200.0.10'
Copy-Item -Path .\PSDEVOPS.Tests.ps1 -ToSession $dc1session -Destination C:\Resources -Force -Verbose
$pesterResult = Invoke-Command -Session $dc1session -ScriptBlock { Import-Module Pester -Force; Invoke-Pester -Path C:\Resources -PassThru }

## Disconnect sessions
Get-PSSession | Remove-PSSession -Verbose

## Stop all lab VMs
Stop-Lab -ConfigurationData $configuration -Verbose

## Create a snaphost of all lab VMs
Checkpoint-Lab -ConfigurationData $configuration -SnapshotName 'PSDEVOPS Build' -Verbose

## Revert the lab to pre-build state
Restore-Lab -ConfigurationData $configuration -SnapshotName 'Lability Baseline Snapshot' -Verbose

## Remove all lab VMs and snapshots
Remove-LabConfiguration -ConfigurationData $configuration -Verbose



## Rebuild lab with different OSes, using the same configuration
$configurationV2 = '.\PSDEVOPSv2.psd1'
Get-Content -Path $configuration |
    ForEach-Object {
        $_ -replace '2012R2_x64_Standard_EN_v5_Eval','2016TP5_x64_Standard_EN' -replace 'Win81_x64_Enterprise_EN_v5_Eval','WIN10_x64_Enterprise_EN_Eval'
    } | Set-Content -Path $configurationV2

Start-LabConfiguration -ConfigurationData .\PSDEVOPSv2.psd1 -Path D:\TestLab\Configurations\ $configurationPath -Credential $labCredential -Verbose -Force


## Ad-hoc VM creation
## ==================

## Force image recreation
#New-LabImage -Id 2016TP4_x64_NANO_EN -Force -Verbose;

## Provision ad-hoc virtual machine
New-LabVM -Name NANO -MediaId 2016TP4_x64_NANO_EN -SwitchName External -Credential $labCredential -Verbose -NoSnapshot | Start-VM -Passthru | %{ vmconnect localhost $_.Name }
Enter-PSSession -ComputerName 10.100.50.115 -Credential $labCredential -Authentication Default

## Delete ad-hoc virtual machine and disks
Remove-LabVM -Name NANO -Verbose
