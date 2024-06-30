$Commands = @(Get-ChildItem -Path $PSScriptRoot\*.ps1)
foreach ($Function in @($Commands)) {
    . $Function.FullName
}

Function Show-AvailableCommands {
    $ShowAvailableCommands = [System.Collections.ArrayList]::new()    
        $global:Module = "AzureSecrets"
        Get-Command -Module $Module | Where-Object {$_.Name -Ne "Show-AvailableCommands"} | ForEach-Object {
           [void]$ShowAvailableCommands.Add([PSCustomObject]@{
                Command = $_.Name | Sort-Object Command
                Type    = $_.CommandType | Sort-Object CommandType
                Module  = $_.Source
            })
        } 
        Write-Host "$($ShowAvailableCommands | Format-Table -AutoSize | Out-String)" -ForegroundColor Yellow
    }
    