<#
.SYNOPSIS
    This function will retrieve Network Security Group Rules in Azure Cloud
.DESCRIPTION
    Use this function as needed, view Network Security Group rules in mass, or even export the rules to a file
.NOTES
   .NOTES
    Version: V.1.0.0
    Date Written: 01/04/2024
    Written By: Nik Chikersal
    CopyRight: (c) Nik Chikersal
    
    Change Log:
    N/A
    v.1.0.0 - 01/04/2024 - Nik Chikersal - Initial Version

.LINK
https://www.powershellgallery.com/packages/AzureCloud
.EXAMPLE
Get-AzureCloudNetworkSecurityGroupRule -Name "NSG-Name"
    This example will retrieve Security Group Rules for a specific Network Security Group in Azure Cloud

Get-AzureCloudNetworkSecurityGroupRule -All
    This example will retrieve Security Group Rules for all Network Security Groups in Azure Cloud

Get-AzureCloudNetworkSecurityGroupRule -All -ExportToFile $True
    This example will retrieve Security Group Rules for all Network Security Groups Azure Cloud and export the output to a .TXT file

Get-AzureCloudNetworkSecurityGroupRule -All -ExportToFile $True -FIleType "csv"
    This example will retrieve Security Group Rules for all Network Security Groups Azure Cloud and export the output to a .CSV file

Get-AzureCloudNetworkSecurityGroupRule -All -ExportToFile $True -FIleType "html"
    This example will retrieve Security Group Rules for all Network Security Groups Azure Cloud and export the output to a .HTML file   
#>
function Get-AzureCloudNetworkSecurityGroupRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [switch]$All,
        [Parameter(Mandatory = $false, Position = 2, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [boolean]$ExportToFile,
        [Parameter(Mandatory = $false, Position = 3, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()][ValidateSet('html', 'csv')]
        [string]$FileType
    )
    
    #param validation to ensure -All OR -Name is used
    if (! $PSCmdlet.MyInvocation.BoundParameters.ContainsKey("All") -and 
    (! $PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Name"))) {
        Write-Error "Script cannot continue, it needs at least one of the following parameters"
        Write-Host "Use the "  -BackgroundColor "Yellow" -ForegroundColor "Red" -NoNewline; Write-Host " -Name" -BackgroundColor "Cyan" -ForegroundColor "Red" -NoNewline; Write-Host " Parameter to display all Resources"  -BackgroundColor "Yellow" -ForegroundColor "Red"
        Write-Host "Use the "  -BackgroundColor "Yellow" -ForegroundColor "Red" -NoNewline; Write-Host " -All" -BackgroundColor "Cyan" -ForegroundColor "Red" -NoNewline; Write-Host " Parameter to display all Resources"  -BackgroundColor "Yellow" -ForegroundColor "Red"
        break
    }

    #If the -FileType Param exists, check if the -ExportToFile Param exists
    if ($FileType) {
        if (!$PSCmdlet.MyInvocation.BoundParameters.ContainsKey(("ExportToFile"))) {
           Write-Error "Script cannot continue, The -FileType Parameter requires the -ExportToFile Parameter"
           break
        }
        #If the -FileType Param exists, check if the -ExportToFile Param is set to $true and NOT $false
        elseif($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("ExportToFile") -and -not ([boolean]::Equals($true, $ExportToFile)) -and ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("FileType"))) {
            Write-Error "Script cannot continue, the -ExportToFile Parameter has to be set to $true when using the -FileType Parameter"
            break
        }
    }
    #Azure subscription validation to ensure subscriptions can be queried with existing permissions
    $global:Results = [System.Collections.ArrayList]::new()
    $Subscriptions = (Get-AzSubscription).Name
     if ([string]::IsNullOrEmpty($Subscriptions)) { 
        Write-Error "Could not find any Subscriptions in this Azure Tenant with current permissions"
        break
    }
    elseif (![string]::IsNullOrEmpty($Subscriptions)) {
     foreach ($Subscription in $Subscriptions) {
        [void](Set-AzContext -Subscription $Subscription)
  try {
    if (! (Get-Command -Name Get-AzNetworkSecurityGroup -ErrorAction SilentlyContinue)) {
        Write-Warning "The required command doesn't exist on this machine. Please re-install the AzureCloud Module to Automatically Install the required AZ Modules"
        break
    }   #If -Name is used, retrieve one NSG record, if -All is used, retrieve all NSG records
        switch ($PSCmdlet.MyInvocation.BoundParameters.Keys) {
            'Name' {
                $NSGs = Get-AzNetworkSecurityGroup -Name $Name
                  if ([string]::IsNullOrEmpty($NSGs)) { 
                     Write-Warning "Could not find the following Network Security Group(s): $($Name)"
                     break
                   }
                }
            'All' {
                $NSGs = Get-AzNetworkSecurityGroup
                  if ([string]::IsNullOrEmpty($NSGs)) { 
                    Write-Warning "Could not find any Network Security Group(s) in the Tenant $(Get-AzDomain).DefaultDomain"
                    break
                   }
                }
            }
        }
        catch {
           return [PSCustomObject][Ordered]@{
                Error   = $global:Error.Exception.Message[0]
                Failure = $global:Error.Failure[0]
            }
        }
        #Convert from JSON and store results into a custom object after the loop
        foreach ($NSG in $NSGs) {
            if ([string]::IsNullOrEmpty($NSGs)) { 
                Write-Warning "Could not find the following Network Security Group(s): $($NSGs)"
                break
            }
            elseif (![string]::IsNullOrEmpty($NSGs)) {
                $NullNSG = $Nsg.SecurityRulesText.ToString().Replace("[]", "")
                  [void][array]$global:Results.Add([PSCustomObject][Ordered]@{
                      Name        = $NSG.Name
                      AzureSub    = $Subscription
                      Action      = if ([string]::IsNullOrEmpty($NullNSG)) {" "} 
                      Else { [string]::Join(", ", ($NSG.SecurityRulesText | ConvertFrom-Json).Access) }
                      RuleName    = if ([string]::IsNullOrEmpty($NullNSG)) {" "} 
                      Else { [string]::Join(", ", ($NSG.SecurityRulesText | ConvertFrom-Json).Name) }
                      Protocol    = if ([string]::IsNullOrEmpty($NullNSG)) {" "} 
                      Else { [string]::Join(", ", ($NSG.SecurityRulesText | ConvertFrom-Json).Protocol) }
                      Source      = if ([string]::IsNullOrEmpty($NullNSG)) {" "} 
                      Else { [string]::Join(", ", ($NSG.SecurityRulesText | ConvertFrom-Json).SourceAddressPrefix).Replace("*", "All IP Addresses") }
                      Dest        = if ([string]::IsNullOrEmpty($NullNSG)) {" "} 
                      Else { [string]::Join(", ", ($NSG.SecurityRulesText | ConvertFrom-Json).DestinationAddressPrefix).Replace("*", "All IP Addresses") }
                      SourceRange = if ([string]::IsNullOrEmpty($NullNSG)) {" "} 
                      Else { [string]::Join(", ", ($NSG.SecurityRulesText | ConvertFrom-Json).SourcePortRange) }
                      DestRange   = if ([string]::IsNullOrEmpty($NullNSG)) {" "}
                      Else { [string]::Join(", ", ($NSG.SecurityRulesText | ConvertFrom-Json).DestinationPortRange) }
                   })
                }
            }
        }
    }
    #Nested switch statement to handle the -ExportToFile Param
    switch ($PSCmdlet.MyInvocation.BoundParameters.Keys) {
        'ExportToFile' {
            if (! $PSCmdlet.MyInvocation.BoundParameters.ContainsKey("FileType")) {
             [array]$global:Results | Out-File -FilePath "$([System.IO.Directory]::GetCurrentDirectory())\$([System.DateTime]::get_Now().ToString().Replace("/", "_").Split(" ")[0])_NSGReport.Txt" 
                    if ((Test-Path -Path "$([System.IO.Directory]::GetCurrentDirectory())\$([System.DateTime]::get_Now().ToString().Replace("/", "_").Split(" ")[0])_NSGReport.txt")) {
                        Write-Host "Exported File to Path: $([System.IO.Directory]::GetCurrentDirectory())\" -ForegroundColor Yellow -NoNewline ; Write-Host "$([System.DateTime]::get_Now().ToString().Replace("/", "_").Split(" ")[0])_NSGReport.txt" -ForegroundColor Green                    
                    }
                }
            #Nested switch statement to handle the -FileType Param    
            switch ($FileType) {
                'csv'  { 
                    [array]$global:Results | Export-Csv -Path "$([System.IO.Directory]::GetCurrentDirectory())\$([System.DateTime]::get_Now().ToString().Replace("/", "_").Split(" ")[0])_NSGReport.$($FileType)" -NoTypeInformation
                    if ((Test-Path -Path "$([System.IO.Directory]::GetCurrentDirectory())\$([System.DateTime]::get_Now().ToString().Replace("/", "_").Split(" ")[0])_NSGReport.$($FileType)")) {
                        Write-Host "Exported File to Path: $([System.IO.Directory]::GetCurrentDirectory())\" -ForegroundColor Yellow -NoNewline ; Write-Host "$([System.DateTime]::get_Now().ToString().Replace("/", "_").Split(" ")[0])_NSGReport.$($FileType)" -ForegroundColor Green
                        [string]$OpenFileExcel = Read-Host "Would you like to open the File in Excel? [Y/N]"   
                          while ($OpenFileExcel -ne "Y" -and $OpenFileExcel -ne "N") {
                            Write-Warning "Invalid Input. Please enter 'Y' or 'N'"
                              [string]$OpenFileExcel = Read-Host "Would you like to open the File in Excel? [Y/N]"
                            }
                            #switch statement to track output and open the exported results as a CSV if chosen
                            switch ($OpenFileExcel) {
                                'Y' { 
                                    try {
                                        if ((Get-Process -Name 'Excel' -ErrorAction SilentlyContinue)) {
                                               Stop-Process -Name 'Excel' -Force
                                        }
                                        [System.Diagnostics.Process]::Start("excel.exe", "$([System.IO.Directory]::GetCurrentDirectory())\$([System.DateTime]::get_Now().ToString().Replace("/", "_").Split(" ")[0])_NSGReport.$($FileType)")
                                    }
                                    catch {
                                      Start-Process -FilePath "$([System.IO.Directory]::GetCurrentDirectory())\$([System.DateTime]::get_Now().ToString().Replace("/", "_").Split(" ")[0])_NSGReport.$($FileType)"
                                        return [PSCustomObject]@{
                                            Error   = $global:Error.Exception.Message 
                                            Failure = $global:Error.Failure
                                        }
                                    }
                                 }
                              'N' { Exit 1 }
                            }
                        }
                    } #If html is chosen on the -FileType Parameter, open HTML file in browser if open              
                     'html' { 
                     [array]$global:Results | ConvertTo-Html -Fragment -As 'Table' | Out-File -FilePath "$([System.IO.Directory]::GetCurrentDirectory())\$([System.DateTime]::get_Now().ToString().Replace("/", "_").Split(" ")[0])_NSGReport.$($FileType)"
                     if ((Test-Path -Path "$([System.IO.Directory]::GetCurrentDirectory())\$([System.DateTime]::get_Now().ToString().Replace("/", "_").Split(" ")[0])_NSGReport.$($FileType)")) {
                       Write-Host "Exported File to Path: $([System.IO.Directory]::GetCurrentDirectory())\" -ForegroundColor Yellow -NoNewline ; Write-Host "$([System.DateTime]::get_Now().ToString().Replace("/", "_").Split(" ")[0])_NSGReport.$($FileType)" -ForegroundColor Green
                       [string]$OpenHTMLFile = Read-Host "Would you like to open the HTML File? [Y/N]"   
                          while ($OpenHTMLFile -ne "Y" -and $OpenHTMLFile -ne "N") {
                            Write-Warning "Invalid Input. Please enter 'Y' or 'N'"
                              [string]$OpenFileExcel = Read-Host "Would you like to open the HTML File? [Y/N]"
                          }
                          switch ($OpenHTMLFile) {
                            'Y' {
                                try {
                                  [System.Diagnostics.Process]::Start("C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe", "$([System.IO.Directory]::GetCurrentDirectory())\$([System.DateTime]::get_Now().ToString().Replace("/", "_").Split(" ")[0])_NSGReport.$($FileType)") 
                                }
                                catch {
                                      return [PSCustomObject]@{
                                          Error   = $global:Error.Exception.Message[0]
                                          Failure = $global:Error.Failure
                                        }
                                    }
                                }
                           'N' {Exit 1} 
                        }
                    }
                }
            }
        }
#If -All parameter is used, check if the -ExportFile parameter is emunerated. void the global var to avoid results outputting while the file exports
        'All' {
          if ($ExportToFile) {
              [void]$global:Results 
        }
        
        else {
         return [array]$global:Results #If -All parameter is used alone, return the custom object with the NSG results
            } 
        }
    }
}

 

