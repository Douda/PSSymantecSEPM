function Get-SEPMCommandStatus {
    <#
    .SYNOPSIS
        Get Command Status Details
    .DESCRIPTION
        Gets the details of a command status
    .PARAMETER SkipCertificateCheck
        Skip certificate check
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
        $Command_ID,

        # Skip certificate check
        [Parameter()]
        [switch]
        $SkipCertificateCheck
    )

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if (-not $test_token) {
            Get-SEPMAccessToken | Out-Null
        }
        if ($SkipCertificateCheck) {
            $script:SkipCert = $true
        }
        $URI = $script:BaseURLv1 + "/command-queue/$command_id"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
    }

    process {
        # prepare the parameters
        $params = @{
            Method  = 'GET'
            Uri     = $URI
            headers = $headers
        }
    
        $resp = Invoke-ABRestMethod -params $params
        return $resp
    }
}