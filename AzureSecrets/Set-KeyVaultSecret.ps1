<#
.AUTHOR
    Nik Chikersal
.SYNOPSIS
    This function is used to Set Secrets in Azure Keyvault from a file or string
.EXAMPLE
    Set-KeyVaultsSecret -SecretName 'MySecret' -SecretValue 'MySecretValue'
    This example shows how to set a secret in the default vault

    Set-KeyVaultsSecret -SecretName 'MySecret' -FilePath
    This example shows how to set a secret in the default vault from a file

    Set-KeyVaultsSecret -KeyVaultName 'MyVault' -SecretName 'MySecret' -FilePath
    This example shows how to set a secret in a specified vault from a file

    Set-KeyVaultsSecret -KeyVaultName 'MyVault' -SecretName 'MySecret' -SecretValue 'MySecretValue'
    This example shows how to set a secret in a specified vault from a string
.NOTES
Ensure you have the proper IAM permissions to the keyvault and secret (s) in question before attempting to download or retrieve them
#>
function Set-KeyVaultSecret {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String]$KeyVaultName,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()][ValidatePattern("^[0-9a-zA-Z-]+$")]
        [string]$SecretName,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$SecretValue,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [switch]$ShowSecretValue
    )
$WindowsXML = "$env:USERPROFILE\Defaults.Xml"
$MacXML = "/Users/$env:USER/Defaults.Xml"

if ($SecretValue -and $FilePath) {
    Write-Warning "Cannot use both secret value and file path parameters"
    break
}

if (!$KeyVaultName -and $IsMacOS) {
    if (Test-Path -Path $MacXML) {
        if (![String]::IsNullOrWhiteSpace((Get-Content -Path $MacXML))) {
            $KeyVaultName = [string](Get-Content -Path $MacXML)
        }
        Else {
            Write-Warning "Default Azure KeyVault found but value is Null or Empty"
            Write-Output  "to Set Default Vault: Set-DefaultKeyVault -SetDefaultKeyVault <VaultName>"
        }
    }
    Else {
        Write-Warning "Default Azure KeyVault not found"
        Write-Output "To Set Default Vault: Set-DefaultKeyVault -SetDefaultKeyVault <VaultName>"
        break
    }
}
    if (!$KeyVaultName -and $IsWindows) {
        if (Test-Path -Path $WindowsXML) {
            if (![String]::IsNullOrWhiteSpace((Get-Content -Path $WindowsXML))) {
                $KeyVaultName = [string](Get-Content -Path $WindowsXML)
            }
            Else {
                Write-Warning "Default Azure KeyVault found but value is Null or Empty"
                Write-Output  "to Set Default Vault: Set-DefaultKeyVault -SetDefaultKeyVault <VaultName>"
            }
        }
        Else {
            Write-Warning "Default Azure KeyVault not found"
            Write-Output "To Set Default Vault: Set-DefaultKeyVault -SetDefaultKeyVault <VaultName>"
            break
        }
    }

   if ($KeyVaultName) { 
          $KeyVaultCheck = Get-AzKeyVault -VaultName $KeyVaultName 
            if ([string]::IsNullOrEmpty($KeyVaultCheck)) {
                Write-Warning "Could not find KeyVault: $($KeyVaultName) in Azure"
                break
            }
       if ($FilePath) {
         if (!(Test-Path -Path $FilePath)) {
            Write-Error "File not found at $FilePath"
            break
        }
        elseif (Test-Path -Path $FilePath) {
            try {
                  (Get-Content -Path $FilePath -Raw) | ForEach-Object {
                        $SecureStringSecret = ConvertTo-SecureString -String $_ -AsPlainText -Force
                             $global:Result = (Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -SecretValue $SecureStringSecret)
                return [PSCustomObject]@{ 
                      SecretName  = $global:Result.Name
                      VaultName   = $global:Result.VaultName
                      Created     = $global:Result.Created
                      Expires     = if ([string]::IsNullOrEmpty($global:Result.Expires)) { "Never" } Else { $global:Result.Expires }
                      SecretValue = if ($ShowSecretValue) { 
                          Get-KeyVaultSecret -SecretName $SecretName 
                      } 
                      Else { 
                        If ((Get-KeyVaultSecret -SecretName $SecretName).ToString().Length -gt "30") {
                            '(Hidden, too many characters to hide) ' + '*' * 30
                        }
                        Else {
                          '(Hidden) ' + '*' * (Get-KeyVaultSecret -SecretName $SecretName).ToString().Length
                       }
                    }
                }
            }
        }
        catch {
            Write-Warning $($Global:Error.Exception.Message)[0]
            }
        }
    }
    elseif ($SecretValue) {
        try {
            $SecureStringSecret = ConvertTo-SecureString -String $SecretValue -AsPlainText -Force
            $global:Result = Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -SecretValue $SecureStringSecret
            return [PSCustomObject]@{ 
                SecretName  = $global:Result.Name
                VaultName   = $global:Result.VaultName
                Created     = $global:Result.Created
                Expires     = if ([string]::IsNullOrEmpty($global:Result.Expires)) { "Never" } Else { $global:Result.Expires }
                SecretValue = if ($ShowSecretValue) { 
                    Get-KeyVaultSecret -SecretName $SecretName 
                } 
                Else { 
                    '(Hidden) ' + '*' * (Get-KeyVaultSecret -SecretName $SecretName).ToString().Length
                    
                }
            }   
        }
        catch {
             Write-Warning $Global:Error.Exception.Message[0]
           }
        }
    }
}
           
        
             
          

    

             
      




    