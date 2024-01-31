function Initialize-PolicyExceptionStructure {

    <#
    .SYNOPSIS
        Initializes the skeleton of the body structure to update the exception policy.
    .DESCRIPTION
        Initializes the skeleton of the body structure to update the exception policy.
        Returns the body structure and its associated policy ID.
    .PARAMETER PolicyName
        The name of the policy to update.
    .NOTES
        This is an internal helper function.
    .EXAMPLE
        PS C:\> Initialize-PolicyExceptionStructure -PolicyName "Default"
    #>
    
    
    [CmdletBinding()]
    param (
        # Policy Name
        [Parameter(
            ValueFromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [String]
        $PolicyName
    )

    process {
        # Get all policies
        $policies = Get-SEPMPoliciesSummary

        # Get Policy ID from policy name
        $PolicyID = $policies | Where-Object { $_.name -eq $PolicyName } | Select-Object -ExpandProperty id

        # Instantiates the skeleton of the body structure to update the exception policy
        $ObjBody = [SEPMPolicyExceptionsStructure]::new()

        # Update the body structure with the mandatory parameters
        $ObjBody.name = $PolicyName

        $return = [PSCustomObject]@{
            ObjBody  = $ObjBody
            PolicyID = $PolicyID
        }

        # Return ObjBody & policy ID
        return $return
    }
    
}