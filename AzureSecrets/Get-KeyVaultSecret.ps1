<#
.AUTHOR
    Nik Chikersal
.SYNOPSIS
    This function is used to Download and Retrieve Secrets from Azure Keyvault
.EXAMPLE
    Set-DefaultKeyVault -DefaultKeyVaultName 'MyAzureVaultName'
    This example shows how to set the default vault 

    Set-DefaultAzureSubscription -SubscriptionName 'MyAzureSubscriptionName'
    This example shows how to set the default subscription

    Get-KeyvaultSecret -SecretName 'MySecret' -DownloadSecret
    This example shows how to download a secret from the default vault

    Get-KeyvaultSecret -SecretName 'MySecret' -KeyVaultName 'MyAzureVaultName'
    This example shows how to download a secret from a specified vault

    Get-KeyvaultSecret -SecretName 'MySecret' -KeyVaultName 'MyAzureVaultName' -DownloadSecret
    This example shows how to download a secret from a specified vault

    Get-KeyvaultSecret -SecretName 'MySecret' -KeyVaultName 'MyAzureVaultName' -DownloadSecret -Filetype xml
    this example shows how to download a secret from a specified vault and save it as an xml file or any other file type from the validate set
.NOTES
Ensure you have the proper IAM permissions to the keyvault and secret (s) in question before attempting to download or retrieve them
#>
function Get-KeyVaultSecret {
    [CmdletBinding()]
    [Alias('Set-DefaultKeyVault', 'Set-DefaultAzureSubscription')]
    param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SecretName,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$KeyVaultName,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$DefaultKeyVaultName,
        [ValidateNotNullOrEmpty()]
        [string]$SubscriptionName,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [switch]$DownloadSecret,
        [Parameter(Mandatory = $false)][ValidateNotNullOrEmpty()]
        [ValidateSet(
            'cer', 'crt', 'pem', 'der', 'p7b', 'p7c', 'p12', 'pfx', 'key', 'pub', 'csr',
            'ppk', 'txt', 'log', 'md', 'xml', 'json', 'yaml', 'csv', 'ini', 'config',
            'conf', 'cfg', 'sh', 'ps1', 'psm1', 'psd1', 'ps1xml', 'psm1xml'
        )]
        [string]$FileType
    )

if (($DefaultKeyVaultName -or $SubscriptionName) -and ($KeyVaultName -or $SecretName -or $DownloadSecret)) {
    Write-Error "Cannot use -DefaultKeyVaultName or -SubscriptionName Parameters with other other Parameters"
    Write-Output "Use the following commands to set default vault and subscription"
    Write-Output "Set-DefaultKeyVault -DefaultKeyVaultName 'MyVaultName'"
    Write-Output "Set-DefaultAzureSubscription -SubscriptionName 'MySubscriptionName'"
    break
}

if (($DownloadSecret -or $FileType) -and (-not $DownloadSecret -or -not $FileType)) {
    Write-Error "If -DownloadSecret or -FileType are used, both parameters must be used together"
    break
}

if (-not [string]::IsNullOrEmpty($SubscriptionName)) {
    if (Get-AzSubscription -SubscriptionName $SubscriptionName -ErrorAction SilentlyContinue) {
        try {
            Set-AzConfig -DefaultSubscriptionForLogin $SubscriptionName
            return   
        }
        catch {
            Write-Warning $($Global:Error.Exception.Message[0])
        }
    }
    else {
         Write-Warning "Could not find Subscription Name $($SubscriptionName) in Azure"
         Start-Sleep -Seconds 10
         Exit 1
       }
    }

$MacXML = "/Users/$env:USER/Defaults.Xml"
$WindowsXML = "$env:USERPROFILE\Defaults.Xml"

    if ($DefaultKeyVaultName) { 
        if ($IsMacOS) {
            Out-File -InputObject $DefaultKeyVaultName -FilePath $MacXML -Force
            if (Test-Path $MacXML) {
               Write-Host "Default KeyVault has been set to $($DefaultKeyVaultName)" -ForegroundColor Green
            }
            Return
        }
        elseif ($IsWindows) {
            Out-File -InputObject $DefaultKeyVaultName -FilePath $WindowsXML -Force
            if (Test-Path $WindowsXML) {
                Write-Host "Default KeyVault has been set to $($DefaultKeyVaultName)" -ForegroundColor Green
            }
            Return
         }
    }

if ((Test-Path -Path $WindowsXML -ErrorAction SilentlyContinue) -or (Test-Path -Path $MacXML -ErrorAction SilentlyContinue) -and [string]::IsNullOrEmpty($KeyVaultName)) { 
     Switch ($IsMacOS) {
        $true  { $KeyVaultName = [string](Get-Content -Path $MacXML) }
        $false { $KeyVaultName = [string](Get-Content -Path $WindowsXML) }
      }
    }
    elseif (-not [string]::IsNullOrEmpty($KeyVaultName)) { $KeyVaultName = $KeyVaultName }

    if (([string]::IsNullOrEmpty($KeyVaultName))) {
        Write-Warning "No values were specified. Please specify a valid valult name or a set a default vault"
        Write-Output "To Set Default Vault: Set-DefaultKeyVault -SetDefaultKeyVault <VaultName>"
        Write-Output "To specifiy a Vault: Get-KeyVaultSecret -KeyVaultName <VaultName>"
        return
    }
    elseif (-not (Get-AzKeyVault -VaultName $KeyVaultName)) {
        Write-Warning "KeyVault: $($KeyVaultName) was not found"
        Write-Output "To Set Default Vault: Set-DefaultKeyVault -SetDefaultKeyVault <VaultName>"
        Write-Output "To Specifiy a Vault: Get-KeyVaultSecret -KeyVaultName <VaultName>"
        return
    }
       $SecretResult = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -AsPlainText
          if ([string]::IsNullOrEmpty($SecretResult)) {
                Write-Warning "Secret $($SecretName) not found in $($KeyVaultName)"
                Start-Sleep -Seconds 3
                try {
                    Get-AzKeyVaultSecret -VaultName $KeyVaultName | Select-Object @{N='ExistingSecrets'; E={$_.Name}}  
                }
                catch {
                    Write-Warning $($Global:Error.Exception.Message)[0]
                }
            }
            elseif (-not ([string]::IsNullOrEmpty($SecretResult))) {
                if ($DownloadSecret) {
                    try {
                        if ($FileType) { $ExportedFile = "$($SecretName).$($FileType)" } Else { $ExportedFile = "$($SecretName).txt" }
                        Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -AsPlainText | Out-File $ExportedFile
                        Write-Host "Azure Secret $($ExportedFile) has been downloaded to $([System.IO.Directory]::GetCurrentDirectory())" -ForegroundColor Yellow
            
                        [string]$OpenFile = Read-Host "Open Exported Secret File? Type 'Y' to Open File Or 'N' to exit"
                        
                        while ($OpenFile -ne 'Y' -and $OpenFile -ne 'N') {
                            Write-Warning "Invalid Answer. Enter Y or N to Continue"
                            [string]$OpenFile = Read-Host "Open Exported Secret File? Type 'Y' to Open File Or 'N' to exit"
                        }
            
                        switch ($OpenFile) {
                            'N' {
                                Write-Host "Exiting..." -ForegroundColor Yellow
                                Exit 1
                            }
                            'Y' {
                                [string]$Platform = Read-Host "Would you like to open the file in VSCode or Notepad? Type 'V' for VSCode or 'N' for Notepad"
            
                                while ($Platform -ne 'V' -and $Platform -ne 'N') {
                                    Write-Warning "Invalid Answer. Enter 'V' for VSCode or 'N' for Notepad to Proceed"
                                    [string]$Platform = Read-Host "Would you like to open the file in VSCode or Notepad? Type 'V' for VSCode or 'N' for Notepad"
                                }
            
                                switch ($Platform) {
                                    'V' {
                                        try {
                                            if ($IsWindows) { 
                                                Code $ExportedFile 
                                            } Elseif ($IsMacOS) { 
                                                Write-Warning "Mac detected: Opening in default app" 
                                                & ./$ExportedFile 
                                            }
                                        } catch {
                                            Write-Warning "VSCode was not detected or there was an error that occured on $(hostname). Opening file in Notepad..."
                                            Notepad $ExportedFile
                                        }
                                    }
                                    'N' { 
                                        try {
                                            if ($IsWindows) { 
                                                NotePad $ExportedFile 
                                        } Elseif ($IsMacOS) { 
                                            Write-Warning "Mac detected: Opening in default app" 
                                            & ./$ExportedFile  
                                        }
                                    } catch {
                                        Write-Warning "Notepad was not detected or there was an error that occured on $(hostname)"
                                      } 
                                   }
                                }
                            }
                        }
                    }
                    catch {
                        Write-Warning $($Global:Error.Exception.Message)[0]
                    }
                }
                else {
                    Return $SecretResult
                }
            }
        }
         
            
