function Get-SEPMCommandStatus {
    <#
    .SYNOPSIS
        Get Command Status Details
    .DESCRIPTION
        Gets the details of a command status
    .EXAMPLE
    PS C:\PSSymantecSEPM> $status = Get-SEPMCommandStatus -Command_ID D17D6DF9877049559910DD7B0306711C

        content          : {@{beginTime=; lastUpdateTime=; computerName=MyWorkstation01; computerIp=192.168.1.1; domainName=Default; currentLoginUserName=localadmin; stateId=0; subStateId=0; subStateDesc=; binaryFileId=; resultInXML=; 
                            computerId=ABCDEF2837CD5C4FD167AD5E2CB31C71; hardwareKey=ABCDEF2837CD5C4FD167AD5E2CB31C71}}
        number           : 0
        size             : 20
        sort             : {@{direction=ASC; property=Begintime; ascending=True}}
        numberOfElements : 1
        firstPage        : True
        totalPages       : 1
        lastPage         : True
        totalElements    : 1

        PS C:\PSSymantecSEPM> $status.content

        beginTime            : 
        lastUpdateTime       : 
        computerName         : MyWorkstation01
        computerIp           : 192.168.1.1
        domainName           : Default
        currentLoginUserName : localadmin
        stateId              : 0
        subStateId           : 0
        subStateDesc         : 
        binaryFileId         : 
        resultInXML          : 
        computerId           : ABCDEF2837CD5C4FD167AD5E2CB31C71
        hardwareKey          : ABCDEF2837CD5C4FD167AD5E2CB31C71

    Gets the status of a command
    .PARAMETER Command_ID  
        The ID of the command to get the status of
#>

    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]
        [Alias("ID", "CommandID")]
        $Command_ID
    )

    begin {
        $session = Initialize-SEPMSession
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPMCommandStatus'
    }

    process {
        $allResults = @()
        $pageParams = @{}

        do {
            $resp = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session -PathIds @($Command_ID) -AdditionalQueryParams $pageParams

            # Process the response
            $allResults += $resp.content

            # Increment the page index
            $pageParams.pageIndex++

        } until ($resp.lastPage -eq $true)

        # Add a PSTypeName to the object 
        $allResults | ForEach-Object {
            $_.PSTypeNames.Insert(0, "SEPM.CommandStatus")
        }
    
        Write-Output $allResults -NoEnumerate
    }
}
