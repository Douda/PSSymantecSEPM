# Set of functions that generate dummy data for testing purposes.
# Their goal is to simulate API calls and return dummy data to test the functions that consume the API responses.

function New-DummyDataSEPMPoliciesSummary {
    <#
.SYNOPSIS
    Generates dummy data for the SEPMPolicyExceptionsStructure class.
.DESCRIPTION
    This function generates dummy data for the SEPMPolicyExceptionsStructure class. 
    by default, it generates dummy data for all policy types with random names and descriptions.
.PARAMETER PolicyName
    The name of the policy.
.PARAMETER PolicyType
    The type of the policy.
    list of policy types: hid, exceptions, mem, ntr, av, fw, ips, lucontent, lu, hi, adc, msl, upgrade
.EXAMPLE
    PS C:\> New-DummyDataSEPMPoliciesSummary -PolicyName "LiveUpdate Servers" -PolicyType "lucontent"
    This command creates a dummy object with the specified policy name and type.
.EXAMPLE
    PS C:\> New-DummyDataSEPMPoliciesSummary
    This command creates dummy objects for all policy types.
.INPUTS
    None. You cannot pipe objects to New-DummyDataSEPMPoliciesSummary.
.OUTPUTS
    System.Management.Automation.PSObject. New-DummyDataSEPMPoliciesSummary returns a PSObject.
#>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(ParameterSetName = 'SinglePolicy', Mandatory = $true)]
        [string]$PolicyName,

        [Parameter(ParameterSetName = 'SinglePolicy', Mandatory = $true)]
        [string]$PolicyType,

        [Parameter(ParameterSetName = 'Default')]
        [int]$PoliciesPerPolicyType = 1
    )

    function New-DummyObject {
        param (
            [string]$PolicyName,
            [string]$PolicyType
        )

        # Generate a 64-character long id containing characters from 0-9 and A-F
        $id = -join ((48..57) + (65..70) | Get-Random -Count 64 | ForEach-Object { [char]$_ })

        # Get the current Unix timestamp in milliseconds
        $lastmodifiedtime = [long]([double]::Parse((Get-Date -UFormat %s)) * 1000)

        # Create a new PSObject with random data for each property
        $dummyObject = New-Object PSObject -Property @{
            sources               = $null
            enabled               = $true
            desc                  = "Random description of " + $PolicyName
            name                  = $PolicyName
            lastmodifiedtime      = $lastmodifiedtime
            id                    = $id
            domainid              = [guid]::NewGuid().ToString()
            policytype            = $PolicyType
            subtype               = $null
            assignedtocloudgroups = $null
            assignedtolocations   = $null
        }

        return $dummyObject
    }

    # Define the list of policy types
    $policytypes = @("hid", "exceptions", "mem", "ntr", "av", "fw", "ips", "lucontent", "lu", "hi", "adc", "msl", "upgrade")

    # Initialize an array to hold the dummy objects
    $dummyObjects = @()

    # If both PolicyName and PolicyType are provided, generate only one dummy object
    if ($PSCmdlet.ParameterSetName -eq 'SinglePolicy') {
        if ($PolicyType -in $policytypes) {
            $dummyObjects += New-DummyObject -PolicyName $PolicyName -PolicyType $PolicyType
        } else {
            Write-Error "Invalid policy type. Please provide one of the following: $($policytypes -join ', ')"
        }
    } else {
        # Loop through each policy type
        foreach ($policytype in $policytypes) {
            # Generate $PoliciesPerPolicyType policies of the same type
            1..$PoliciesPerPolicyType | ForEach-Object {
                $dummyObjects += New-DummyObject -PolicyName ("policy " + $policytype + " " + $_) -PolicyType $policytype
            }
        }
    }

    # Return the array of dummy objects
    return $dummyObjects
}

function New-DummyDataSEPComputers {
    <#
.SYNOPSIS
    Generates a dummy SEP Computer object for testing purposes.
.DESCRIPTION
    Generates a dummy SEP Computer object for testing purposes.
    They're supposed to look similar to the ones returned by the Get-SEPComputers cmdlet.
.PARAMETER ComputerName
    Generates a dummy SEP Computer object with the specified computer name.
.EXAMPLE
    1..3 | New-DummyDataSEPComputers

    group             : @{id=7c4d2d27-d7e0-43ef-8c75-008383312b62; name=My Company\\test group 88;
                        fullPathName=; externalReferenceId=; source=; domain=}
    ipAddresses       : {112.157.108.212, B126:712F:8D34:4788:EBC0:E515:CBFD:B31F}
    macAddresses      : {45-65-5A-0A-78-58, 45-65-5A-0A-78-58}
    gateways          : {25.93.38.195, 49.27.148.201, 161.106.231.189, 21.186.123.6}
    subnetMasks       : {79.71.18.0, 64}
    dnsServers        : {15.54.206.121, 1F5B:9FFA:C68D:8B99:0ED2:1993:6285:CF63}
    winServers        : {246.94.104.55, 246.94.104.55}
    description       : Description of computer id: 7c4d2d27-d7e0-43ef-8c75-008383312b62
    computerName      : WIN-7653
    lastInventoryDate : 28/02/2024 17:18:47
    lastModifiedDate  : 28/02/2024 17:18:47
    createdDate       : 28/02/2024 17:18:47
    createdBy         : User36
    lastModifiedBy    : User67
    version           : 8
    deleted           : False

    Generates 3 dummy SEP Computer objects for testing purposes.
#>
    [CmdletBinding()]
    param (
        # ComputerName
        [Parameter()]
        [String]
        $ComputerName,

        # GroupName
        [Parameter()]
        [String]
        $GroupName
    )

    process {
        $customObject = New-Object PSObject
        # ComputerName
        if ($ComputerName) {
            $customObject | Add-Member -Type NoteProperty -Name "computerName" -Value $ComputerName
        } else {
            $customObject | Add-Member -Type NoteProperty -Name "computerName" -Value ("WIN-" + (Get-Random -Minimum 1 -Maximum 10000))
        }
        $group = New-Object PSObject
        # GroupName
        if ($GroupName) {
            $group | Add-Member -Type NoteProperty -Name "name" -Value $GroupName
        } else {
            $group | Add-Member -Type NoteProperty -Name "name" -Value ("My Company\\test group " + (Get-Random -Minimum 1 -Maximum 100))
        }
        $group | Add-Member -Type NoteProperty -Name "id" -Value ([guid]::NewGuid().ToString())
        $group | Add-Member -Type NoteProperty -Name "fullPathName" -Value $null
        $group | Add-Member -Type NoteProperty -Name "externalReferenceId" -Value $null
        $group | Add-Member -Type NoteProperty -Name "source" -Value $null

        # Domain from the group
        $domain = New-Object PSObject
        $domain | Add-Member -Type NoteProperty -Name "id" -Value ([guid]::NewGuid().ToString())
        $domain | Add-Member -Type NoteProperty -Name "name" -Value "Default"
        $group | Add-Member -Type NoteProperty -Name "domain" -Value $domain
        $customObject | Add-Member -Type NoteProperty -Name "group" -Value $group

        # IpAddresses
        $ipv4 = ((1..4 | ForEach-Object { Get-Random -Minimum 1 -Maximum 255 }) -join '.')
        $ipv6 = ((1..8 | ForEach-Object { "{0:X4}" -f (Get-Random -Minimum 0x0000 -Maximum 0xFFFF) }) -join ':')
        $customObject | Add-Member -Type NoteProperty -Name "ipAddresses" -Value @($ipv4, $ipv6)

        # MacAddresses
        $mac = ((1..6 | ForEach-Object { "{0:X2}" -f (Get-Random -Minimum 0 -Maximum 256) }) -join '-')
        $customObject | Add-Member -Type NoteProperty -Name "macAddresses" -Value @(1..2 | ForEach-Object { $mac })

        # Gateways
        $gateways = @(1..4 | ForEach-Object { ((1..4 | ForEach-Object { Get-Random -Minimum 1 -Maximum 255 }) -join '.') })
        $customObject | Add-Member -Type NoteProperty -Name "gateways" -Value $gateways

        # SubnetMasks
        $subnetMasks = @((ForEach-Object { (1..3 | ForEach-Object { Get-Random -Minimum 1 -Maximum 255 }) -join '.' }) + ".0")
        $customObject | Add-Member -Type NoteProperty -Name "subnetMasks" -Value @($subnetMasks, "64")

        # DnsServers
        $dnsv4 = ((1..4 | ForEach-Object { Get-Random -Minimum 1 -Maximum 255 }) -join '.')
        $dnsv6 = ((1..8 | ForEach-Object { "{0:X4}" -f (Get-Random -Minimum 0x0000 -Maximum 0xFFFF) }) -join ':')
        $customObject | Add-Member -Type NoteProperty -Name "dnsServers" -Value @($dnsv4, $dnsv6)

        # WinServers
        $Wins = ((1..4 | ForEach-Object { Get-Random -Minimum 1 -Maximum 255 }) -join '.')
        $customObject | Add-Member -Type NoteProperty -Name "winServers" -Value @(1..2 | ForEach-Object { $Wins })

        $customObject | Add-Member -Type NoteProperty -Name "description" -Value ("Description of computer id: " + $group.id)
        $customObject | Add-Member -Type NoteProperty -Name "lastInventoryDate" -Value (Get-Date)
        $customObject | Add-Member -Type NoteProperty -Name "lastModifiedDate" -Value (Get-Date)
        $customObject | Add-Member -Type NoteProperty -Name "createdDate" -Value (Get-Date)
        $customObject | Add-Member -Type NoteProperty -Name "createdBy" -Value ("User" + (Get-Random -Minimum 1 -Maximum 100))
        $customObject | Add-Member -Type NoteProperty -Name "lastModifiedBy" -Value ("User" + (Get-Random -Minimum 1 -Maximum 100))
        $customObject | Add-Member -Type NoteProperty -Name "version" -Value (Get-Random -Minimum 1 -Maximum 10)
        $customObject | Add-Member -Type NoteProperty -Name "deleted" -Value $false

        # $customObject.PSTypeNames.Insert(0, "SEP.Computer")
        return $customObject
    }
}