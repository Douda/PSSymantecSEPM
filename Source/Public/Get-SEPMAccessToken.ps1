    Test-CertificateSelfSigned -URI $URI_Authenticate

    $Params = @{
        Method      = 'POST'
        Uri         = $URI_Authenticate
        ContentType = "application/json"
        Body        = ($body | ConvertTo-Json)
    }

    $Response = Invoke-ABRestMethod -params $Params
