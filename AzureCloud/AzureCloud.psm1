.$PSScriptRoot\Get-AzureCloudNetworkSecurityGroupRule.ps1
.$PSScriptRoot\Connect-Azure.ps1

Function Show-AvailableCommands {
    $ShowAvailableCommands = [System.Collections.ArrayList]::new()    
        $global:Module = "AzureCloud"
        Get-Command -Module $Module | Where-Object {$_.Name -Ne "Show-AvailableCommands"} | ForEach-Object {
           [void]$ShowAvailableCommands.Add([PSCustomObject]@{
                Command = $_.Name | Sort-Object Command
                Type    = $_.CommandType | Sort-Object CommandType
                Module  = $_.Source
            })
        } 
        Write-Host "$($ShowAvailableCommands | Format-Table -AutoSize | Out-String)" -ForegroundColor Yellow
    }