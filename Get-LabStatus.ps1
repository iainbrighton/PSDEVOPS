<#
    .SYNOPSIS
        Queries computers' LCM state to determine whether an existing DSC configuration has applied.

    .EXAMPLE
        .\Get-LabStatus.ps1 -ComputerName CONTROLLER, XENAPP

        Queries the CONTROLLER and XENAPP computers' LCM state.

    .EXAMPLE
        .\Get-LabStatus.ps1 -ComputerName CONTROLLER, EXCHANGE -Credential (Get-Credential)

        Prompts for credentials to connect to the CONTROLLER and EXCHANGE computers to query the LCM state.

    .EXAMPLE
        .\Get-LabStatus.ps1 -ConfigurationData .\TestLabGuide.psd1 -Credential (Get-Credential)

        Prompts for credentials to connect to the computers defined in the DSC configuration document (.psd1) and query the LCM state.
#>
#requires -Version 4
[CmdletBinding()]
param (
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ComputerName')]
    [System.String[]]
    $ComputerName,

    [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ConfigurationData')]
    [System.Collections.Hashtable]
    [Microsoft.PowerShell.DesiredStateConfiguration.ArgumentToConfigurationDataTransformationAttribute()]
    $ConfigurationData,

    [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'ConfigurationData')]
    [System.String]
    $PreferNodeProperty,

    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.CredentialAttribute()]
    $Credential
)

if ($PSCmdlet.ParameterSetName -eq 'ConfigurationData') {
    $nodes = $ConfigurationData.AllNodes | Where-Object { $_.NodeName -ne '*' };
    foreach ($node in $nodes) {
        $nodeName = $node.NodeName;
        if (($PSBoundParameters.ContainsKey('PreferNodeProperty')) -and
            (-not [System.String]::IsNullOrEmpty($node[$PreferNodeProperty]))) {

            $nodeName = $node[$PreferNodeProperty];
        }
        $ComputerName += $nodeName;
    }
}

$sessions = Get-PSSession;
$activeSessions = @();
$inactiveSessions = @();

foreach ($computer in $computerName) {

    $session = $sessions | Where { $_.ComputerName -eq $computer -and $_.State -eq 'Opened' } | Select-Object -First 1;
    if (-not $session) {
        if (-not (Test-WSMan -ComputerName $computer -ErrorAction SilentlyContinue)) {
            Write-Warning -Message ("Computer '$computer' not reachable.");
            $inactiveSessions += $computerName;
        }
        else {
            $newPSSessionParams = @{
                ComputerName = $computer;
                Authentication = 'Default';
            }
            if ($PSBoundParameters.ContainsKey('Credential')) {
                $newPSSessionParams['Credential'] = $Credential;
            }
            Write-Verbose -Message ("Connecting to '$computer'.");
            $activeSessions += New-PSSession @newPSSessionParams;
        }
    }
    else {
        Write-Verbose ("Using existing session to '$computer'.");
        $activeSessions += $session
    }
}

Write-Verbose -Message ("Querying active session(s) '$($activeSessions.ComputerName -join "','")'.");
$results = Invoke-Command -Session $activeSessions -ScriptBlock { Get-DscLocalConfigurationManager | Select-Object -Property LCMVersion,LCMState; };

foreach ($computer in $ComputerName) {
    if ($computer -in $inactiveSessions) {
        [PSCustomObject] @{
            ComputerName = $inactiveSession;
            LCMVersion = '';
            LCMState = 'Unknown';
            Completed = $false;
        }
    }
    else {
        $result = $results | Where-Object { $_.PSComputerName -eq $computer };
        [PSCustomObject] @{
            ComputerName = $result.PSComputerName;
            LCMVersion = $result.LCMVersion;
            LCMState = $result.LCMState;
            Completed = $result.LCMState -eq 'Idle';
        }
    }
}
