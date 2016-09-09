<#
    Modified example from:

        https://pshirwin.wordpress.com/2016/03/25/active-directory-configuration-snapshot/
        https://pshirwin.wordpress.com/2016/04/08/active-directory-operations-test/
#>

$adConfiguration = @{
    Forest = @{
        FQDN = 'psdevops.local'
        ForestMode = 'Windows2012R2Forest'
        GlobalCatalogs = @(
            'DC1.psdevops.local'
        )
        SchemaMaster = 'DC1.psdevops.local'
        DomainNamingMaster = 'DC1.psdevops.local'

    }
    Domain = @{
        NetBIOSName = 'PSDEVOPS'
        DomainMode = 'Windows2012R2Domain'
        RIDMaster = 'DC1.psdevops.local'
        PDCEmulator = 'DC1.psdevops.local'
        InfrastructureMaster = 'DC1.psdevops.local'
        DistinguishedName = 'DC=psdevops,DC=local'
        DNSRoot = 'psdevops.local'
        DomainControllers = @('DC1')
    }
}

Describe 'Active Directory configuration operational readiness' {

    Import-Module ActiveDirectory -Verbose:$false -Force

    Context 'Verifying Forest Configuration'{

        $forestConfiguration = Get-ADForest

        It "Forest FQDN $($ADConfiguration.Forest.FQDN)" {
            $adConfiguration.Forest.FQDN | Should Be $forestConfiguration.RootDomain
        }
        
        It "ForestMode $($ADConfiguration.Forest.ForestMode)" {
            $adConfiguration.Forest.ForestMode | Should Be $forestConfiguration.ForestMode.ToString()
        }

    } #end context Verifying Forest Configuration

    Context 'Verifying GlobalCatalogs' {

        $forestConfiguration = Get-ADForest

        foreach ($globalCatalog in $adConfiguration.Forest.GlobalCatalogs) {

            It "Server $globalCatalog is a GlobalCatalog" {
                $forestConfiguration.GlobalCatalogs.Contains($globalCatalog) | Should Be $true
            }
        
        }

    } #end context Verifying GlobalCatalogs

    Context 'Verifying Domain Configuration' {
        
        $adDomain = Get-ADDomain
        $adDomainControllers = Get-ADDomainController -Filter *

        It "Total Domain Controllers $($adConfiguration.Domain.DomainControllers.Count)" {

            @($adDomainControllers).Count | Should Be @($adConfiguration.Domain.DomainControllers).Count
        }

        foreach ($domainController in $adConfiguration.Domain.DomainControllers) {
            
            It "DomainController $domainController exists" {
                $adDomainControllers.Name.Contains($domainController) | Should Be $true
            }

        }

        It "DNSRoot $($adConfiguration.Domain.DNSRoot)" {
            $adDomain.DNSRoot | Should Be $adConfiguration.Domain.DNSRoot
        }
        
        It "NetBIOSName $($adConfiguration.Domain.NetBIOSName)"{
            $adDomain.NetBIOSName | Should Be $adConfiguration.Domain.NetBIOSName
        }
        
        It "DomainMode $($adConfiguration.Domain.DomainMode)"{
            $adDomain.DomainMode.ToString() | Should Be $adConfiguration.Domain.DomainMode
        }

        It "DistinguishedName $($adConfiguration.Domain.DistinguishedName)" {
            $adDomain.DistinguishedName | Should Be $adConfiguration.Domain.DistinguishedName
        }

        It "Server $($adConfiguration.Domain.RIDMaster) is RIDMaster" {
            $adDomain.RIDMaster | Should Be $adConfiguration.Domain.RIDMaster
        }

        It "Server $($adConfiguration.Domain.PDCEmulator) is PDCEmulator" {
            $adDomain.PDCEmulator | Should Be $adConfiguration.Domain.PDCEmulator
        }

        It "Server $($adConfiguration.Domain.InfrastructureMaster) is InfrastructureMaster" {
            $adDomain.InfrastructureMaster | Should Be $adConfiguration.Domain.InfrastructureMaster
        }

    } #end context Verifying Domain Configuration

} #end describe Active Directory configuration operational readiness
