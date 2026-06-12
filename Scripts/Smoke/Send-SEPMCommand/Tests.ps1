<#
.SYNOPSIS
    Shared smoke tests for Send-SEPMCommand.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: ActiveScan, FullScan, Quarantine, UpdateContent, GetFile,
            ClearIronCache with various computers and parameters.
#>

$results = @{}

$results.A1 = T "A1" "ActiveScan with real computer" `
    { Send-SEPMCommand -Type ActiveScan -ComputerName 'WIN-P093KPK2K7Q' } `
    { param($r) $r -ne $null }

$results.A2 = T "A2" "ActiveScan with non-existent computer" `
    { Send-SEPMCommand -Type ActiveScan -ComputerName 'NonExistentComputer12345' } `
    { param($r) $r -ne $null }

$results.A3 = T "A3" "ActiveScan via pipeline" `
    { 'WIN-P093KPK2K7Q' | Send-SEPMCommand -Type ActiveScan } `
    { param($r) $r -ne $null }

$results.F1 = T "F1" "FullScan with real computer" `
    { Send-SEPMCommand -Type FullScan -ComputerName 'WIN-P093KPK2K7Q' } `
    { param($r) $r -ne $null }

$results.F2 = T "F2" "FullScan with non-existent computer" `
    { Send-SEPMCommand -Type FullScan -ComputerName 'NonExistentComputer12345' } `
    { param($r) $r -ne $null }

$results.Q1 = T "Q1" "Quarantine with real computer" `
    { Send-SEPMCommand -Type Quarantine -ComputerName 'WIN-P093KPK2K7Q' } `
    { param($r) $r -ne $null }

$results.Q2 = T "Q2" "Quarantine with -Undo" `
    { Send-SEPMCommand -Type Quarantine -ComputerName 'WIN-P093KPK2K7Q' -Undo } `
    { param($r) $r -ne $null }

$results.U1 = T "U1" "UpdateContent with real computer" `
    { Send-SEPMCommand -Type UpdateContent -ComputerName 'WIN-P093KPK2K7Q' } `
    { param($r) $r -ne $null }

$results.U2 = T "U2" "UpdateContent with non-existent computer" `
    { Send-SEPMCommand -Type UpdateContent -ComputerName 'NonExistentComputer12345' } `
    { param($r) $r -ne $null }

$results.G1 = T "G1" "GetFile SHA256 with non-existent computer" `
    { Send-SEPMCommand -Type GetFile -ComputerName 'NonExistentPC_Smoke' -SHA256 'ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890' -FilePath 'C:\Temp\malware.exe' } `
    { param($r) $r -ne $null }

$results.G2 = T "G2" "GetFile MD5 with non-existent computer" `
    { Send-SEPMCommand -Type GetFile -ComputerName 'NonExistentPC_Smoke' -MD5 'ABCDEF1234567890ABCDEF1234567890' -FilePath 'C:\Temp\test.dll' } `
    { param($r) $r -ne $null }

$results.G3 = T "G3" "GetFile SHA1 with non-existent computer" `
    { Send-SEPMCommand -Type GetFile -ComputerName 'NonExistentPC_Smoke' -SHA1 'ABCDEF1234567890ABCDEF1234567890ABCDEF12' -FilePath 'C:\Temp\binary.sys' -Source 'BOTH' } `
    { param($r) $r -ne $null }

$results.I1 = T "I1" "ClearIronCache SHA256 with non-existent computer" `
    { Send-SEPMCommand -Type ClearIronCache -ComputerName 'NonExistentPC_Smoke' -SHA256 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' } `
    { param($r) $r -ne $null }

$results.I2 = T "I2" "ClearIronCache MD5 with non-existent computer" `
    { Send-SEPMCommand -Type ClearIronCache -ComputerName 'NonExistentPC_Smoke' -MD5 'd41d8cd98f00b204e9800998ecf8427e' } `
    { param($r) $r -ne $null }

$results.GRP1 = T "GRP1" "ActiveScan via GroupName" `
    { Send-SEPMCommand -Type ActiveScan -GroupName 'My Company\APJ' } `
    { param($r) $r -ne $null }

$results.GRP2 = T "GRP2" "FullScan via GroupName" `
    { Send-SEPMCommand -Type FullScan -GroupName 'My Company\APJ' } `
    { param($r) $r -ne $null }

$results.PIPE1 = T "PIPE1" "ActiveScan multiple computers via pipeline" `
    { 'WIN-P093KPK2K7Q', 'NonExistentComputer12345' | Send-SEPMCommand -Type ActiveScan } `
    { param($r) $r -ne $null }

Write-Summary -Results $results -Label "Send-SEPMCommand Smoke Tests"
