 <#
.AUTHOR
    Nik Chikersal
.SYNOPSIS
    This function is used to Renew Secrets for Azure App Registrations
.EXAMPLE
    Update-ClientSecrets -MailboxSender Someone@Domain.com -TeamsWebHookURL https://outlook.office.com/webhook/12345
    This example shows how to Renew Client secrets for Azure App Registrations and send a Teams Message if a failure occurs
.NOTES
Ensure this Script is being run in an Azure Automation Account with PWSH 7.2+, using an MSI with the proper RBAC Permissions.

#>


function Update-ClientSecrets {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MailboxSender,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$KeyVaultName,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TeamsWebHookURL
    )

try {
    Connect-AzAccount -Identity | Out-Null 
}
catch {
    Write-Warning $Global:Error.Exception.Message[0]
}

if ($env:Username -or $env:USER -ne "ContainerUser") {
    Write-Warning "This Script must be run in an Azure Automation Account (Run on Azure)"
    Start-Sleep -Seconds 10
    Exit 1
}

$BearerToken = Get-GraphAccessToken -UseMSI

[hashtable]$AppSplatArgs = @{
    Headers = @{Authorization = "Bearer $($BearerToken)"}
    Uri     = 'https://graph.microsoft.com/v1.0/applications'
    Method  = 'GET'
}

Connect-MgGraph -Identity -NoWelcome | Out-Null

(Invoke-RestMethod @AppSplatArgs).Value

$Results = [System.Collections.ArrayList]::new()

$Date     = Get-Date
$Tomorrow = $Date.AddDays(1).ToString().Split(" ")[0]
$Today    = $Date.ToString().Split(" ")[0]
$Time     = Get-Date -Format hh:mm

(Invoke-RestMethod @AppSplatArgs).Value | 
    Where-Object {$_.PasswordCredentials.Enddatetime.count -gt "0"} | ForEach-Object {
      $AppReg = $_
      $AppReg.PasswordCredentials.Enddatetime | 
        ForEach-Object { $_.ToString("M/dd/yyy") | 
          ForEach-Object {
           $SecretExpiryDate = $_

      [hashtable]$AppOwnerSplatArgs = @{
            Headers =  @{Authorization = "Bearer $($BearerToken)"}
            Uri     =  "https://graph.microsoft.com/v1.0/applications/$($AppReg.ID)/Owners"
            Method  =  'GET'
        }
        
        (Invoke-RestMethod @AppownerSplatArgs).Value | ForEach-Object {
        $AppRegOwnerSMTP = $_
       
        $CustomObject = [PSCustomObject]@{
            AppName          = $AppReg.DisplayName
            SecretName       = $AppReg.PasswordCredentials.DisplayName
            SecretExpiryDate = $SecretExpiryDate
            SecretKeyID      = $AppReg.PasswordCredentials.KeyID
            AppID            = $AppReg.ID
            AppOwner         = $AppRegOwnerSMTP.mail
        }
       [void]$Results.Add($CustomObject)
      }
    }
  }
}
      $ExpiringSecrets = [System.Collections.ArrayList]::new()

      $Results | Where-Object {$_.SecretExpiryDate.Equals($Tomorrow)} | ForEach-Object {
      $Expiring = $_

         $Object = [PSCustomObject][Ordered]@{
             AppName          = $Expiring.AppName 
             SecretName       = $Expiring.SecretName 
             SecretExpiryDate = $Expiring.SecretExpiryDate
             SecretKeyID      = $Expiring.SecretKeyID 
             AppID            = $Expiring.AppID
             AppOwner         = $Expiring.AppOwner
         }
        $ExpiringSecrets.Add($Object)
      }
      
      if ( -not [string]::IsNullOrEmpty($ExpiringSecrets)) {
        Write-Output "The following Secrets are expiring soon:"
        $ExpiringSecrets | Format-Table -AutoSize
       }
        else { 
         Write-Warning "There are no App Registrations with Secrets close to Expiry"
         Exit 1
       }
        
$ExpiringSecrets | ForEach-Object {
    $SecretToRemove = $_
    [Array]$SecretToRemove.SecretKeyID | ForEach-Object {
        $SecretKeyID = $_    

        $RemoveSecretParams = @{
            KeyId = $SecretKeyID
        }

        try {
            Write-Output "Removing Secret: $SecretKeyID from $($SecretToRemove.AppName)"
            Start-Sleep -Seconds 10

          [hashtable]$SecretRemovalArgs = @{
                ApplicationId = $SecretToRemove.AppID
                BodyParameter = $RemoveSecretParams
                ErrorAction   = 'STOP'
            }
            Remove-MgApplicationPassword @SecretRemovalArgs 
        } 
        catch {
            Write-Output "Failed to remove secret $($Error[0].Exception.Message)"
        }
    }
}
$RenewedSecretsResultsArray = [System.Collections.ArrayList]::new()

$ExpiringSecrets | ForEach-Object {
    $SecretToRenew = $_
    $SecretToRenew.SecretName | ForEach-Object {
    $SecretName = $_
    
$TrimmedOldSecret = [System.Text.RegularExpressions.Regex]::Replace($SecretName, ": Renewed.*", "")

  $RenewSecretParams = @{
      passwordCredential = @{
          DisplayName = "$($TrimmedOldSecret): Renewed $Today - $Time"
          EndDateTime = (Get-Date).AddMonths(3)
      }
  }

   try {
    [hashtable]$SecretRenewalArgs = @{
         ApplicationId = $SecretToRenew.AppID
         BodyParameter = $RenewSecretParams
      }
      Start-Sleep -Seconds 14
      Write-Output "Renewing Secrets for $($Expiring.AppName): $($Expiring.AppID)"
      $Result = Add-MgApplicationPassword @SecretRenewalArgs
      [void]$RenewedSecretsResultsArray.Add($Result)
    }
    catch {
        Write-Output "There was an Error renewing the Secret for $($Expiring.AppName)"
           [PSCustomObject][Ordered]@{
            Failure           = $Error.Exception.Message
            AdditionalDetails = $Error.FullyQualifiedErrorId
            ErrorID           = $Error.Errors
            $ErrorDetails     = $Error.ErrorDetails
           }
        }
    }
}

    try {
      Connect-AzAccount -Identity | Out-Null
      $RenewedSecretsResultsArray | ForEach-Object {
      $KeyVaultSecret = $_
      
      $SecretNamePrefix      = $KeyVaultSecret.DisplayName.Split(" ").Replace(" ", "").Replace(":", "")[0]
      $SecretType            = "-" + $KeyVaultSecret.DisplayName.Replace(":", "").Split(" ")[1]
      $ConstructedSecretName = $SecretToRenew.AppName + "-" + $SecretNamePrefix + $SecretType
      $EncryptedSecret = ConvertTo-SecureString -String $KeyVaultSecret.SecretText -AsPlainText -Force
    
      [hashtable]$KeyVaultArgs = @{
          VaultName   = $KeyVaultName
          Name        = $ConstructedSecretName
          SecretValue = $EncryptedSecret
      }
        Set-AzKeyVaultSecret @KeyVaultArgs | ForEach-Object {

        Write-Output ""
        Write-Output ""
        Write-Output "Creating Secret $($_.Name) in $($KeyVaultArgs.VaultName)"
        }
    }
}   catch {
        Write-Output "There was an Error renewing the Secret for $($Expiring.AppName)"
           [PSCustomObject][Ordered]@{
             Failure           = $Error.Exception.Message
             AdditionalDetails = $Error.FullyQualifiedErrorId
             ErrorID           = $Error.Errors
             $ErrorDetails     = $Error.ErrorDetails
            }
            $TeamsError = $Expiring.AppName | Out-String 
           
           $JsonBody = [PSCustomObject][Ordered]@{
            "@type"      = "MessageCard"
            "@context"   = "http://schema.org/extensions"
            "summary"    = "One or More Application Registrations have failed to Renew Secrets"
            "themeColor" = "0078D7"
            "title"      = "One or More Application Registrations have failed to Renew Secrets"
            "text"       = "Application Registration Failed to Renew One or More Secrets: 
            App Reg Name: $($TeamsError)"
            }

           $TeamMessageBody = ConvertTo-Json $JsonBody -Depth 100
           [hashtable]$WebhookArgs = @{
             "URI"         = $TeamsWebHookURL
             "Method"      = 'POST'
             "Body"        = $TeamMessageBody
             "ContentType" = 'application/json'
            }
             Invoke-RestMethod @WebhookArgs -ErrorAction SilentlyContinue
            }
      
      $EmailTop  = [string]"<h2>One or More App Registration Secrets are Expiring</h2>
      <br>"
      $EmailBody = $ExpiringSecrets | 
                     Select-Object AppName, SecretExpiryDate, 
                     @{N='Secrets'; E={($_.SecretName -join ', ')}} | 
                     ConvertTo-Html -Fragment | 
                     Out-String -Width 10
                     
     $EmailBody = $EmailTop + $EmailBody
     $ExpiringSecrets | 
     Where-Object {$_.AppOwner -ne $null} | ForEach-Object { 
     $AppOwnerPrimarySMTP = $_.AppOwner
     $Subject             = "Alert: One or More App Registration Secrets are Expiring" 

     try {
           Send-GraphEmail -MailboxSender $MailboxSender -MailboxRecipient $AppOwnerPrimarySMTP -Subject $Subject -EmailBody $EmailBody -UseMSI  
     }
     catch {
             Write-Output "$($Error[0].Exception.Message)"
     } 
       }
         }  
  