function Export-SEPMExceptionPolicyToExcel {
    <# TODO update help
    .SYNOPSIS
        A short one-line action-based description, e.g. 'Tests if a function is valid'
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        Information or caveats about the function e.g. 'This function is not supported in Linux'
    .LINK
        Specify a URI to a help page, this will show when Get-Help -Online is used.
    .EXAMPLE
        Test-MyTestFunction -Verbose
        Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
    #>
    
    
    param (
        # Skip certificate check
        [Parameter()]
        [switch]
        $SkipCertificateCheck,
        
        # Policy Name
        [Parameter(
            ValueFromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [String]
        $PolicyName,
        
        # Path
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                # Validate the path
                if (-Not (Split-Path $_ -Parent | Test-Path)) {
                    throw "Directory of `$_` does not exist"
                }
                # Validate the file extension
                if (-Not ($_ -match '\.xlsx$')) {
                    throw "File `$_` does not have the .xlsx extension"
                }
                return $true
            })]
        [string]
        $Path
    )

    begin {

    }

    process {
        # Get Exception policy object
        $ExceptionPolicy = Get-SEPMExceptionPolicy -PolicyName $PolicyName -SkipCertificateCheck:$SkipCertificateCheck

        # Verify the PSObject typename is "SEPM.ExceptionPolicy"
        if ($ExceptionPolicy.PSObject.TypeNames[0] -ne "SEPM.ExceptionPolicy") {
            $message = "The policy name provided is not of type Exception Policy or does not exist - Please verify the policy name"
            Write-Error -Message $message
            throw $message
        }

        # Extract the categories from the exception policy
        $Files = $ExceptionPolicy.configuration.files
        $Folders = $ExceptionPolicy.configuration.directories

        # Excel export parameters
        $excel_params = @{
            ClearSheet   = $true
            BoldTopRow   = $true
            AutoSize     = $true
            FreezeTopRow = $true
            AutoFilter   = $true
        }

        # Define the properties to export
        $filesProperties = @("SONAR", "scancategory", "pathvariable", "path", "applicationcontrol", "securityrisk", "recursive")
        $foldersProperties = @("scancategory", "scantype", "pathvariable", "directory", "recursive")

        # Export the data to Excel
        $Files | ConvertTo-FlatObject | Select-Object -Property $filesProperties | Export-Excel -Path $Path -WorksheetName "Files" @excel_params
        $Folders | ConvertTo-FlatObject | Select-Object -Property $foldersProperties | Export-Excel -Path $Path -WorksheetName "Folders" @excel_params
        
    }
}