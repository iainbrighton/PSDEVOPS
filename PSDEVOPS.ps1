Configuration PSDEVOPS {

    param (
        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Credential = (Get-Credential -Credential 'Administrator')
    )

    Import-DscResource -Module xComputerManagement, xNetworking, xActiveDirectory;
    Import-DscResource -Module PSDesiredStateConfiguration, xPSDesiredStateConfiguration;
    Import-DscResource -Module xSmbShare, xDHCPServer, xDnsServer;

    node $AllNodes.Where({$true}).NodeName {

        LocalConfigurationManager {

            RebootNodeIfNeeded   = $true;
            AllowModuleOverwrite = $true;
            ConfigurationMode = 'ApplyOnly';
            CertificateID = $node.Thumbprint;
        }

        if (-not [System.String]::IsNullOrEmpty($node.IPAddress)) {

            xIPAddress 'PrimaryIPAddress' {
                IPAddress      = $node.IPAddress;
                InterfaceAlias = $node.InterfaceAlias;
                SubnetMask     = $node.SubnetMask;
                AddressFamily  = $node.AddressFamily;
            }

            if (-not [System.String]::IsNullOrEmpty($node.DefaultGateway)) {
                xDefaultGatewayAddress 'PrimaryDefaultGateway' {
                    InterfaceAlias = $node.InterfaceAlias;
                    Address = $node.DefaultGateway;
                    AddressFamily = $node.AddressFamily;
                }
            }
            
            if (-not [System.String]::IsNullOrEmpty($node.DnsServerAddress)) {
                xDnsServerAddress 'PrimaryDNSClient' {
                    Address        = $node.DnsServerAddress;
                    InterfaceAlias = $node.InterfaceAlias;
                    AddressFamily  = $node.AddressFamily;
                }
            }
            
            if (-not [System.String]::IsNullOrEmpty($node.DnsConnectionSuffix)) {
                xDnsConnectionSuffix 'PrimaryConnectionSuffix' {
                    InterfaceAlias = $node.InterfaceAlias;
                    ConnectionSpecificSuffix = $node.DnsConnectionSuffix;
                }
            }
            
        } #end if IPAddress
        
        xFirewall 'FPS-ICMP4-ERQ-In' {
            Name = 'FPS-ICMP4-ERQ-In';
            DisplayName = 'File and Printer Sharing (Echo Request - ICMPv4-In)';
            Description = 'Echo request messages are sent as ping requests to other nodes.';
            Direction = 'Inbound';
            Action = 'Allow';
            Enabled = 'True';
            Profile = 'Any';
        }

        xFirewall 'FPS-ICMP6-ERQ-In' {
            Name = 'FPS-ICMP6-ERQ-In';
            DisplayName = 'File and Printer Sharing (Echo Request - ICMPv6-In)';
            Description = 'Echo request messages are sent as ping requests to other nodes.';
            Direction = 'Inbound';
            Action = 'Allow';
            Enabled = 'True';
            Profile = 'Any';
        }

        xPackage 'GitForWindows' {
            Name = 'Git version 2.10.0';
            ProductId = '';
            Arguments = '/VERYSILENT /NORESTART /NOCANCEL /SP-';
            Path = 'C:\Resources\Git-2.10.0-64-bit.exe';
            InstalledCheckRegKey = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Git_is1';
            InstalledCheckRegValueName = 'URLInfoAbout';
            InstalledCheckRegValueData = 'https://git-for-windows.github.io/';
        }

    } #end nodes ALL
  
    node $AllNodes.Where({$_.Role -in 'DC'}).NodeName {
        ## Flip credential into username@domain.com
        $domainCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ("$($Credential.UserName)@$($node.DomainName)", $Credential.Password);

        xComputer 'Hostname' {
            Name = $node.NodeName;
        }
        
        ## Hack to fix DependsOn with hypens "bug" :(
        foreach ($feature in @(
                'AD-Domain-Services',
                'GPMC',
                'RSAT-AD-Tools',
                'DHCP',
                'RSAT-DHCP')) {
            
            WindowsFeature $feature.Replace('-','') {
                Ensure = 'Present';
                Name = $feature;
                IncludeAllSubFeature = $true;
            }
        }
        
        xADDomain 'ADDomain' {
            DomainName = $node.DomainName;
            SafemodeAdministratorPassword = $Credential;
            DomainAdministratorCredential = $Credential;
            DependsOn = '[WindowsFeature]ADDomainServices';
        }

        xDhcpServerAuthorization 'DhcpServerAuthorization' {
            Ensure = 'Present';
            DependsOn = '[WindowsFeature]DHCP','[xADDomain]ADDomain';
        }
        
        xDhcpServerScope 'DhcpScope10_0_0_0' {
            Name = 'Corpnet';
            IPStartRange = '10.200.0.100';
            IPEndRange = '10.200.0.200';
            SubnetMask = '255.255.255.0';
            LeaseDuration = '00:08:00';
            State = 'Active';
            AddressFamily = 'IPv4';
            DependsOn = '[WindowsFeature]DHCP';
        }

        xDhcpServerOption 'DhcpScope10_0_0_0_Option' {
            ScopeID = '10.200.0.0';
            DnsDomain = $node.DomainName;
            DnsServerIPAddress = '10.200.0.10';
            Router = $node.DefaultGateway;
            AddressFamily = 'IPv4';
            DependsOn = '[xDhcpServerScope]DhcpScope10_0_0_0';
        }
        
        xADUser PSDEVOPSUser { 
            DomainName = $node.DomainName;
            UserName = 'PSDEVOPS';
            Description = 'PSDEVOPS Demo Lab user';
            Password = $Credential;
            Ensure = 'Present';
            DependsOn = '[xADDomain]ADDomain';
        }
        
        xADGroup DomainAdmins {
            GroupName = 'Domain Admins';
            MembersToInclude = 'PSDEVOPS';
            DependsOn = '[xADUser]PSDEVOPSUser';
        }
        
        xADGroup EnterpriseAdmins {
            GroupName = 'Enterprise Admins';
            GroupScope = 'Universal';
            MembersToInclude = 'PSDEVOPS';
            DependsOn = '[xADUser]PSDEVOPSUser';
        }

    } #end nodes DC
    
    node $AllNodes.Where({$_.Role -notin 'DC'}).NodeName {

        ## Flip credential into username@domain.com
        $upn = '{0}@{1}' -f $Credential.UserName, $node.DomainName;
        $domainCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ($upn, $Credential.Password);

        xComputer 'DomainMembership' {
            Name = $node.NodeName;
            DomainName = $node.DomainName;
            Credential = $domainCredential;
        }
    } #end nodes DomainJoined
    
    node $AllNodes.Where({$_.Role -in 'APP'}).NodeName {

        ## Flip credential into username@domain.com
        $upn = '{0}@{1}' -f $Credential.UserName, $node.DomainName;
        $domainCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ($upn, $Credential.Password);

        foreach ($feature in @(
                'Web-Default-Doc',
                'Web-Dir-Browsing',
                'Web-Http-Errors',
                'Web-Static-Content',
                'Web-Http-Logging',
                'Web-Stat-Compression',
                'Web-Filtering',
                'Web-Mgmt-Tools',
                'Web-Mgmt-Console')) {
            WindowsFeature $feature.Replace('-','') {
                Ensure = 'Present';
                Name = $feature;
                IncludeAllSubFeature = $true;
                DependsOn = '[xComputer]DomainMembership';
            }
        }

        File 'FilesFolder' {
            DestinationPath = 'C:\Files';
            Type = 'Directory';
        }

        File 'ExampleTxt' {
            DestinationPath = 'C:\Files\Example.txt'
            Type = 'File';
            Contents = 'This is a shared file.';
            DependsOn = '[File]FilesFolder';
        }

        xSmbShare 'FilesShare' {
            Name = 'Files';
            Path = 'C:\Files';
            ChangeAccess = 'PSDEVOPS\PSDEVOPS';
            DependsOn = '[File]FilesFolder';
            Ensure = 'Present';
        }

    } #end nodes APP

} #end Configuration Example
