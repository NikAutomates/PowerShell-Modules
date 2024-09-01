<#
.SYNOPSIS
   This function retrieves an access token (bearer) from the Graph API
.DESCRIPTION
    This function may be used local to retrieve an access token, or by creating a credential in an Azure Automation Account
.NOTES
    Author: Nik Chikersal
    Date: 4/12/2024
    Version: V1.0.0
    Change Log: N/A
.LINK
https://www.powershellgallery.com/packages/Graph/

.EXAMPLE
    Get-BearerToken -ClientID "8c193358-c9c9-4255e-acd8c28f4a" -TenantName "Domain.com" -Secret 'Mysecret'
    This example will allow you to retrieve a bearer token locally, by providing the Client App Secret from Azure AD

    Get-BearerToken -ClientID "8c193358-c9c9-4255e-acd8c28f4a" -TenantName "Domain.com" -RunbookUserName "ClientSecret-Graph"
    This example will retrieve a bearer token from the credential in the Automation Account and autmatically set it on the Runbooks canvas

    Get-BearerToken -UseMSI
    This example will retrieve a bearer token from the MSI being used in the Azure Automation and Runbook
#>
function Get-BearerToken {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = [boolean]$true, ValueFromPipelineByPropertyName = [boolean]$true)]
        [ValidateNotNullOrEmpty()][ValidateLength('30', '36')]
        [string]$ClientID,
        [Parameter(Mandatory = $false, Position = 1, ValueFromPipeline = [boolean]$true, ValueFromPipelineByPropertyName = [boolean]$true )]
        [ValidateNotNullOrEmpty()]
        [string]$TenantName,
        [Parameter(Mandatory = $false, Position = 6)]
        [string]$Secret,
        [Parameter(Mandatory = $false, Position = 4, ValueFromPipeline = [boolean]$true, ValueFromPipelineByPropertyName = [boolean]$true)]
        [string]$RunbookUsername,
        [Parameter(Mandatory = $false, Position = 5)]
        [switch]$UseMSI
    )

    if (-not $PSCmdlet.MyInvocation.BoundParameters["Secret"] -and
       (-not $PSCmdlet.MyInvocation.BoundParameters["RunbookUsername"] -and
       (-not $PSCmdlet.MyInvocation.BoundParameters["UseMSI"]))) {
        throw "You must include at least one of the following parameters: -Secret, -RunbookUserName, -UseMSI"
    }

    switch ($PSCmdlet.MyInvocation.BoundParameters.Keys) {
        "Secret" {
            if (-not $PSCmdlet.MyInvocation.BoundParameters.Keys.Equals("RunbookUserName")) {
                if (-not [string]::IsNullOrEmpty($Secret)) {
                    if ($Secret.Length -gt "30") {

                        [hashtable]$Body = [System.Collections.Specialized.OrderedDictionary]::new()
                        [hashtable]$TokenSplat = [System.Collections.Specialized.OrderedDictionary]::new()

                        [hashtable]$Body.Add("Grant_Type", [string]"client_credentials")
                        [hashtable]$Body.Add("Scope", [string]"https://graph.microsoft.com/.default")
                        [hashtable]$Body.Add("client_Id ", [string]$clientID)
                        [hashtable]$Body.Add("Client_Secret", [string]$Secret)
                        [hashtable]$TokenSplat.Add("Uri", [string]"https://login.microsoftonline.com/$TenantName/oauth2/v2.0/token")
                        [hashtable]$TokenSplat.Add("Method", [string]"POST")
                        [hashtable]$TokenSplat.Add("Body", [hashtable]$Body)

                        try {
                            $global:Token = (Invoke-RestMethod @TokenSplat).access_token
                            return $global:Token   
                        }
                        catch [System.Exception] {
                            throw $global:Error[0].Exception.Message
                        }
                    }
                    else {
                        throw "Secret must be 36 characters"
                    }
                }
                else {
                    throw "Secret must not be null or empty"
                }
            }
        }
        "RunbookUsername" {
            if (-not $PSCmdlet.MyInvocation.BoundParameters.Keys.Equals("Secret")) {

                if (-not (Get-Command -Name 'Get-AutomationPSCredential' -ErrorAction SilentlyContinue)) {
                    throw "Please ensure this command is being used in an Azure Runbook"
                }
            
                [hashtable]$Body = [System.Collections.Specialized.OrderedDictionary]::new()
                [hashtable]$TokenSplat = [System.Collections.Specialized.OrderedDictionary]::new()

                [hashtable]$Body.Add("Grant_Type", [string]"client_credentials")
                [hashtable]$Body.Add("Scope", [string]"https://graph.microsoft.com/.default")
                [hashtable]$Body.Add("client_Id ", [string]$clientID)
                [hashtable]$Body.Add("Client_Secret", (Get-AutomationPSCredential -Name $RunbookUsername).GetNetworkCredential().Password)
                [hashtable]$TokenSplat.Add("Uri", [string]"https://login.microsoftonline.com/$TenantName/oauth2/v2.0/token")
                [hashtable]$TokenSplat.Add("Method", [string]"POST")
                [hashtable]$TokenSplat.Add("Body", [hashtable]$Body)
                
                try {
                    (Invoke-RestMethod @TokenSplat).access_token  
                }
                catch [System.Exception] {
                    throw $global:Error[0].Exception.Message
                }
            }
        }
        "UseMSI" {
            if ($PSCmdlet.MyInvocation.BoundParameters.Keys.Contains("ClientID") -or
               ($PSCmdlet.MyInvocation.BoundParameters.Keys.Contains("TenantName") -or
               ($PSCmdlet.MyInvocation.BoundParameters.Keys.Contains("Secret") -or
               ($PSCmdlet.MyInvocation.BoundParameters.Keys.Contains("RunbookUsername"))))) {
                throw 'You must only use the -UseMSI Parameter while using an MSI in a Runbook'

            }
            else {
                try {
                    function Get-GraphAccessToken {
                        [CmdletBinding()]
                        param (
                            [Parameter(Mandatory = $false)]
                            [ValidateNotNullOrEmpty()]
                            [switch]$UseMSI
                        )
                        
                        if ($UseMSI) {
                            try {
                                [void](Connect-AzAccount -Identity)
                                $ResourceURL = "https://graph.microsoft.com"
                                $global:BearerToken = [string](Get-AzAccessToken -ResourceUrl $ResourceURL).Token 
                                return $global:BearerToken      
                            }
                            catch {
                                Write-Warning $Error.Exception[0]
                            }
                        }
                        else {
                            try {
                                if (Get-Command -Name Connect-AzAccount) {
                                    [void](Connect-AzAccount)
                                    $ResourceURL = "https://graph.microsoft.com"
                                    $global:BearerToken = [string](Get-AzAccessToken -ResourceUrl $ResourceURL).Token
                                    return $global:BearerToken    
                                }
                            }
                            catch {
                                Write-Warning $Error.Exception[0]
                            }
                        }
                    }
                    [string](Get-GraphAccessToken -UseMSI) #This cmlet runs from Azure Secrets Module 
                }
                catch [System.Exception] {
                    throw $global:Error[0].Exception.Message
                }
            }
        }
    }
}
   