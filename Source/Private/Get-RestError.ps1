function Get-RestError($Err) {
    #Allows backwards compatibility with older versions of Powershell
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        if ($Err.Exception.Response) {  
            $Reader = New-Object System.IO.StreamReader($Err.Exception.Response.GetResponseStream())
            $Reader.BaseStream.Position = 0
            $Reader.DiscardBufferedData()
            $ResponseBody = $Reader.ReadToEnd()
            if ($ResponseBody.StartsWith('{')) {
                $ResponseBody = $ResponseBody | ConvertFrom-Json
            }
            return $ResponseBody
        } else {
            return $Err.ErrorDetails.Message
        }
    }
}