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

        # Add the categories to the PSObject
        $ExceptionCategory = [PSCustomObject]@{
            Files           = $ExceptionPolicy.configuration.files
            Folders         = $ExceptionPolicy.configuration.directories
            Certificates    = $ExceptionPolicy.configuration.certificates
            Tamper_files    = $ExceptionPolicy.configuration.tamper_files
            Webdomain       = $ExceptionPolicy.configuration.webdomains
            Mac             = $ExceptionPolicy.configuration.mac.files
            Linux           = $ExceptionPolicy.configuration.linux.directories
            Linux_Extension = $ExceptionPolicy.configuration.linux.extension_list
            KnownRisks      = $ExceptionPolicy.configuration.knownrisks
        }

        # Define the properties to export
        $Props = [PSCustomObject]@{
            Files           = @("scancategory", "pathvariable", "path", "SONAR", "applicationcontrol", "securityrisk", "recursive")
            Folders         = @("scancategory", "scantype", "pathvariable", "directory", "recursive")
            Certificates    = @("*")
            Tamper_files    = @("pathvariable", "path")
            Webdomain       = @("domain")
            Mac             = @("pathvariable", "path")
            Linux           = @("scancategory", "pathvariable", "directory", "recursive")
            Linux_Extension = @("*")
            KnownRisks      = @("threat.id", "threat.name", "action")
        }

        # Define Excel export parameters
        $excel_params = @{
            ClearSheet   = $true
            BoldTopRow   = $true
            AutoSize     = $true
            FreezeTopRow = $true
            AutoFilter   = $true
        }

        # Export the data to Excel
        foreach ($category in $ExceptionCategory.PSObject.Properties.Name) {
            # Only export the category if it has data
            if ($ExceptionCategory.$category) {
                # Special case for Extensions. Split in an array of objects for correct formating
                if ($category -eq "Linux_Extension") {
                    $Extensions = @()
                    foreach ($line in $ExceptionCategory.Linux_Extension.extensions) {
                        $obj = New-Object -TypeName PSObject
                        $obj | Add-Member -MemberType NoteProperty -Name Extensions -Value $line
                        $Extensions += $obj
                    }
                    $Extensions | Select-Object -Property $Props.$category | Export-Excel -Path $Path -WorksheetName $category @excel_params
                    continue
                }
                $ExceptionCategory.$category | ConvertTo-FlatObject | Select-Object -Property $Props.$category | Export-Excel -Path $Path -WorksheetName $category @excel_params
            }
        }
    }
}