 <#
.AUTHOR
    Nik Chikersal
.SYNOPSIS
    This function is used to send emails using the Graph REST API instead of using the Send-MailMessage Cmdlet
.EXAMPLE
    Send-GraphEmail -MailboxSender Someone@Domain.com -MailboxRecipient Someone2@Domain.com -Subject "Test Email" -EmailBody "This is a test email"
    This example shows how to send an email using the Graph REST API

    Send-GraphEmail -MailboxSender Someone@Domain.com -MailboxRecipient Someone2@Domain.com -Subject "Test Email" -EmailBody "This is a test email" -UseMSI
    This example shows how to send an email using the Graph REST API using MSI

.NOTES
Ensure the proper Graph Permissions are grant to the Runbook or User sending the email
#>


Function Send-GraphEmail {
  [CmdletBinding()]
  param (
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [string]$MailboxSender,
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [string]$MailboxRecipient,
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [string]$Subject,
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [string]$EmailBody,
      [Parameter(Mandatory = $false)]
      [ValidateNotNullOrEmpty()]
      [switch]$UseMSI
  )

If ($UseMSI) {

$Headers = @{
  "Authorization" = "Bearer $(Get-GraphAccessToken -UseMSI)"
  "Content-type"  = "application/json" }
}
Else 
{
  $Headers = @{
  "Authorization" = "Bearer $(Get-GraphAccessToken)"
  "Content-type"  = "application/json"}
}

$URLsend = "https://graph.microsoft.com/v1.0/users/$MailBoxSender/sendMail"
$JsonBodyEmail = @"
{
"message": {
"subject": "$Subject",
"body": {
"contentType": "HTML",
"content": "$EmailBody <br>
<br>
<br>
THIS IS AN AUTOMATED MESSAGE, DO NOT REPLY DIRECTLY TO THIS MESSAGE AS IT IS SENT FROM AN UNMONITORED MAILBOX <br>

"
},
"toRecipients": [
{
  "emailAddress": {
    "address": "$mailboxRecipient"
  }
}
]
},
"saveToSentItems": "false"
}
"@

$EmailSendArgs = @{
      Method  = 'POST'
      Uri     = $URLsend
      Headers = $headers
      Body    = $JsonBodyEmail
  }
  try {
  Invoke-RestMethod @EmailSendArgs
  }
  catch {
    Write-Output "Please ensure the Runbook or User has the correct graph permissions to Send from $($MailboxSender)"
   }
} 