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
        }
        @{
            NodeName                    = 'DC1';
            IPAddress                   = '10.200.0.10';
            DnsServerAddress            = '127.0.0.1';
            Role                        = 'DC';
        }
        @{
            NodeName                    = 'APP1';
            IPAddress                   = '10.200.0.11';
            Role                        = 'APP';
        }
        @{
            NodeName                    = 'CLIENT1';
            Role                        = 'CLIENT';
        }
    );
};
