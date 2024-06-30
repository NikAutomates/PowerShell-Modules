<#
.SYNOPSIS
    This function will Start an Azure Virtual Machine and Send an Email Alert if it fails to start
.DESCRIPTION
    Use this function as needed, Runbook (with MSI) or as Human Account
.NOTES
    Version: V.1.0.0
    Date Written: 01/04/2024
    Written By: Nik Chikersal
    CopyRight: (c) Nik Chikersal
    
    Change Log:
    N/A
    v.1.0.0 - 04/01/2024 - Nik Chikersal - Initial Version

.LINK
https://www.powershellgallery.com/packages/AzureVirtualMachines
.EXAMPLE
Start-AzureVM -VMName DC1 -ResourceGroupName RG-Compute -MailboxSender nik@domain.com -MailboxRecipient alerts@domain.com -UseMSI
    This example will start an Azure Virtual Machine within an Azure Runbok in an Automation Account

 Start-AzureVM -VMName DC1 -ResourceGroupName RG-Compute -MailboxSender nik@domain.com -MailboxRecipient alerts@domain.com -UseMSI
    This example will start an Azure Virtual Machine within an a termina/PowerShell Window using a Client ID or UPN
#>
function Start-AzureVM {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false)]
        [switch]$UseMSI,
        [parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$VMName,
        [parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$MailboxSender,
        [parameter(Mandatory = $true, Position = 3)]
        [ValidateNotNullOrEmpty()]
        [string]$MailboxRecipient,
        [parameter(Mandatory = $false)]
        [switch]$UseHumanAccount,
        [parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName
    )

    if (! $PSCmdlet.MyInvocation.BoundParameters.ContainsKey("UseHumanAccount") -and 
    (! $PSCmdlet.MyInvocation.BoundParameters.ContainsKey("UseMSI"))) {
        Write-Error "Script cannot continue without -UseMSI or -UseHumanAccount Parameters"
        break
    }
 
           $Global:Result = [System.Collections.ArrayList]::new()
            switch ($PSCmdlet.MyInvocation.BoundParameters.Keys) {
 
                "UseMSI" {
                    [void](Connect-AzAccount)
                    $Subs = Get-AzSubscription
                    foreach ($sub in $Subs) {
                        [void](Set-AzContext -Subscription $sub.Name)
                        $Global:VMCheck = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
                        if (-not [string]::IsNullOrEmpty($VMCheck)) {    
                            try {
                                Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force 
                            }
                            catch {
                                $Global:Result.Add([PSCustomObject][ordered]@{
                                        Msg   = "There was an error starting virtual machine $($VMCheck.Name)"
                                        Error = $global:Error[0].Exception.Message
                                    })
                                $Global:HTMLEmailBodyError = $Result | ConvertTo-Html -As Table -Fragment | Out-String -Width 10
                                [hashtable]$EmailSendSplat = @{
                                    MailboxSender    = [string]$MailboxSender
                                    MailboxRecipient = [string]$MailboxRecipient
                                    Subject          = [string]"Alert: There was an error starting virtual machine $($VMCheck.Name)"
                                    EmailBody        = $HTMLEmailBodyError
 
                                }
                                Send-GraphEmail @EmailSendSplat
                            }
                        }
                    }
                }
                "UseHumanAccount" {
                    [void](Connect-AzAccount)
                    $Subs = Get-AzSubscription
                    foreach ($sub in $Subs) {
                        [void](Set-AzContext -Subscription $sub.Name)
                        $Global:VMCheck = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
                        if (-not [string]::IsNullOrEmpty($VMCheck)) {
                            try {
                                Start-AzureVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
                            }
                            catch {
                                $Global:Result.Add([PSCustomObject][ordered]@{
                                        Msg   = "There was an error starting virtual machine $($VMCheck.Name)"
                                        Error = $global:Error[0].Exception.Message
                                    })
                                $Global:HTMLEmailBodyError = $Result | ConvertTo-Html -As Table -Fragment | Out-String -Width 10
                                [hashtable]$EmailSendSplat = @{
                                    MailboxSender    = [string]$MailboxSender
                                    MailboxRecipient = [string]$MailboxRecipient
                                    Subject          = [string]"Alert: There was an error starting virtual machine $($VMCheck.Name)"
                                    EmailBody        = $HTMLEmailBodyError
 
                                }
                                Send-GraphEmail @EmailSendSplat
                            }
                        }
                    }
                }
            }
        }