 <#
.AUTHOR
    Nik Chikersal
.SYNOPSIS
    This function is used to retrieve an access token (bearer) from Microsoft Graph
.EXAMPLE
    Get-GraphAccessToken -UseMSI
    This example shows how to retrieve an access token using MSI

    Get-GraphAccessToken
    This example shows how to retrieve an access token without using MSI
.NOTES
#>

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
    Else {
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

    
