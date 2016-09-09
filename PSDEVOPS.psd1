@{
    AllNodes = @(
        @{
            NodeName                    = '*';
            InterfaceAlias              = 'Ethernet';
            DefaultGateway              = '10.200.0.2';
            SubnetMask                  = 24;
            AddressFamily               = 'IPv4';
            DnsServerAddress            = '10.200.0.10';
            DomainName                  = 'psdevops.local';
            
            #CertificateFile             = "$env:AllUsersProfile\Lability\Certificates\LabClient.cer";
            #Thumbprint                  = '5940D7352AB397BFB2F37856AA062BB471B43E5E';
            PSDscAllowPlainTextPassword = $true;
            PSDscAllowDomainUser        = $true; # Removes 'It is not recommended to use domain credential for node X' messages
            
            Lability_SwitchName         = 'NAT';
            Lability_ProcessorCount     = 1;
            Lability_StartupMemory      = 2GB;
            Lability_Media              = '2012R2_x64_Standard_EN_v5_Eval';
            Lability_Resource           = @('Git-2.10.0');
           
        }
        @{
            NodeName                    = 'DC1';
            IPAddress                   = '10.200.0.10';
            DnsServerAddress            = '127.0.0.1';
            Role                        = 'DC';
            
            Lability_ProcessorCount     = 2;
            Lability_BootOrder          = 10;
            Lability_BootDelay          = 60;
        }
        @{
            NodeName                    = 'APP1';
            IPAddress                   = '10.200.0.11';
            Role                        = 'APP';
            
            Lability_BootOrder          = 50;
        }
        @{
            NodeName                    = 'CLIENT1';
            Role                        = 'CLIENT';
                                        
            Lability_Media              = 'Win81_x64_Enterprise_EN_v5_Eval';
            Lability_BootOrder          = 60;
        }
    );
    NonNodeData = @{
        Lability = @{
            EnvironmentPrefix = 'PSDEVOPS-';
            Network = @(
                ## Create Hyper-V switches; see Lability\about_Networking for more details
                ## @{ Name = 'NAT'; Type = 'Internal'; }
            );
            DSCResource = @(
                ## Download published version from the PowerShell Gallery
                @{ Name = 'xComputerManagement'; MinimumVersion = '1.3.0.0'; Provider = 'PSGallery'; }
                ## If not specified, the provider defaults to the PSGallery.
                @{ Name = 'xPSDesiredStateConfiguration'; MinimumVersion = '3.13.0.0'; }
                @{ Name = 'xSmbShare'; MinimumVersion = '1.1.0.0'; }
                @{ Name = 'xNetworking'; MinimumVersion = '2.7.0.0'; }
                @{ Name = 'xActiveDirectory'; MinimumVersion = '2.9.0.0'; }
                @{ Name = 'xDnsServer'; MinimumVersion = '1.5.0.0'; }
                @{ Name = 'xDhcpServer'; MinimumVersion = '1.3.0.0'; }
                ## The 'GitHub' provider can download modules directly from a GitHub repository, for example:
                ## @{ Name = 'Lability'; Provider = 'GitHub'; Owner = 'VirtualEngine'; Repository = 'Lability'; Branch = 'dev'; }
            );
            Resource = @(
                ## Download required resources, see Lability\about_CustomResources for more details
                @{  Id = 'Git-2.10.0';
                    Filename = 'Git-2.10.0-64-bit.exe'
                    Uri = 'https://github.com/git-for-windows/git/releases/download/v2.10.0.windows.1/Git-2.10.0-64-bit.exe'; }
            );
            Module = @(
                ## Download required modules
                @{ Name = 'GitHubRepository'; MinimumVersion = '1.2.0'; }
                @{ Name = 'Pester'; MinimumVersion = '3.4.3'; }
                @{ Name = 'PoshSpec'; MinimumVersion = '2.1.10'; }
                @{ Name = 'OperationValidation'; MinimumVersion = '1.0.1'; }
                @{ Name = 'PSake'; MinimumVersion = '4.6.0'; }
                @{ Name = 'PSDeploy'; MinimumVersion = '0.1.18'; }
                @{ Name = 'PSReadline'; MinimumVersion = '1.2'; }
            );
        };
    };
};
