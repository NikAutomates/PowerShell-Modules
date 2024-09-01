 
<#
.SYNOPSIS
    This function performs REST API Calls against the Graph API Endpoints
.DESCRIPTION
    This function can be used with a bearer token you retrieve, or by escrowing a bearer token which is called as a nested function
.NOTES
    Author: Nik Chikersal
    Date: 4/12/2024
    Version: V1.1.0

    If using -UseMSI Param, ensure the script is running in an Azure Automation Account within a PowerShell Runbook 
    Change Log:
    4/16/2024 - Added additional param validation and -BearerToken as optional positional param
    8/26/2024 - Removed MSAL - Deprecation is soon, delegated auth parameter removed.
    8/26/2024 - Added String Null check after pagination, as some API endpoints and entities do not have 'value' in the object as a property
    8/26/2024 - Include optional choice of JSON Payload during POST, Since some endpoints do not require a payload

.LINK
https://www.powershellgallery.com/packages/Graph/
     
.EXAMPLE
    Invoke-GraphAPIRequest -ClientID "8c193358-c9c9-4255e-acd8c28f4a" -TenantName "MyDomain.com" -URL "https://graph.microsoft.com/v1.0/devices" -Method GET -RunbookUserName "ClientSecret-Graph"
    This example will retrieve a bearer token from the credential in the Automation Account and autmatically set it on the Runbooks canvas, then perform a REST API Call
 
    Invoke-GraphAPIRequest -ClientID "8c193358-c9c9-4255-bc0e-acd8c28f4a" -TenantName "MyDomain.com" -URL "https://graph.microsoft.com/v1.0/devices" -Method GET -Secret 'Mysecret'
    This example will retrieve a bearer token from the clientSecret entered into the prompt, then perform a REST API Call
 
    Invoke-GraphAPIRequest -URL "https://graph.microsoft.com/v1.0/devices" -Method GET -AccessToken "ZiVm9waEZQWjVsd1lxMHB3V2wtdmxsUXBYSkpTTkkiLCJhbGciOiJSUzI1NiIsIng1dCI6In"
    This example will allow you to pass in your own Bearer Token and perform a REST API call

    Invoke-GraphAPIRequest -URL "https://graph.microsoft.com/v1.0/devices" -Method GET -UseMSI 
    This example will allow you to retrieve a bearer token using an MSI and perform a REST API Call

    Invoke-GraphAPIRequest -ClientID "8c193358-c9c9-4255e-acd8c28f4a" -TenantName "MyDomain.com" -URL "https://graph.microsoft.com/v1.0/devices" -Method POST -JsonBody $body -RunbookUserName "ClientSecret-Graph"
    This example will retrieve a bearer token from the credential in the Automation Account and autmatically set it on the Runbooks canvas, then perform a POST REST API Call
 
    Invoke-GraphAPIRequest -ClientID "8c193358-c9c9-4255-bc0e-acd8c28f4a" -TenantName "MyDomain.com" -URL "https://graph.microsoft.com/v1.0/devices" -Method POST -JsonBody $body -Secret 'Mysecret'
    This example will retrieve a bearer token from the clientSecret entered into the prompt, then perform a POST REST API Call
 
    Invoke-GraphAPIRequest -URL "https://graph.microsoft.com/v1.0/devices" -Method POST -JsonBody $body -AccessToken "ZiVm9waEZQWjVsd1lxMHB3V2wtdmxsUXBYSkpTTkkiLCJhbGciOiJSUzI1NiIsIng1dCI6In"
    This example will allow you to pass in your own Bearer Token and perform a POST REST API call

    Invoke-GraphAPIRequest -URL "https://graph.microsoft.com/v1.0/devices" -Method POST -NoJsonBody -AccessToken "ZiVm9waEZQWjVsd1lxMHB3V2wtdmxsUXBYSkpTTkkiLCJhbGciOiJSUzI1NiIsIng1dCI6In"
    This example will allow you to pass in your own Bearer Token and perform a POST REST API call with no JSON Body when not required

    Invoke-GraphAPIRequest -URL "https://graph.microsoft.com/v1.0/devices" -Method GET -UseMSI
    This example will allow you to retrieve a bearer token using an MSI and perform a POST REST API Call
#>
function Invoke-GraphAPIRequest {
    [CmdletBinding()]
    [Alias('Invoke-APIRequest')] 
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ArgumentCompleter({
                param(
                    [string]$commandName,
                    [string]$parameterName,
                    [string]$wordToComplete,
                    [System.Management.Automation.Language.CommandAst]$commandAst,
                    [System.Collections.IDictionary]$fakeBoundParameters
                )

                [array]$GraphURLs = [System.Collections.Generic.List[object]](
                    'https://graph.microsoft.com/v1.0/users',
                    'https://graph.microsoft.com/v1.0/groups'
                )

                $ArgCompletionResults = [System.Collections.Generic.List[System.Management.Automation.CompletionResult]]::new()
                foreach ($Url in $GraphURLs) {
                    if ($Url -like "$wordToComplete*") {
                        [void]$ArgCompletionResults.Add(
                            [System.Management.Automation.CompletionResult]::new($Url, $Url, 'ParameterValue', $Url)
                        )
                    }
                }
             return $ArgCompletionResults
         })]
        [ValidatePattern('^https?')]
        [ValidateNotNullOrEmpty()]
        [string]$GraphURL,
        [Parameter(Mandatory = $false, ValueFromPipeline = [boolean]$true, ValueFromPipelineByPropertyName = [boolean]$true)]
        [ValidateNotNullOrEmpty()][ValidateLength('30', '36')]
        [string]$ClientID,
        [Parameter(Mandatory = $false, ValueFromPipeline = [boolean]$true, ValueFromPipelineByPropertyName = [boolean]$true)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantName,
        [Parameter(Mandatory = $true, ValueFromPipeline = [boolean]$true, ValueFromPipelineByPropertyName = [boolean]$true)]
        [ValidateSet("GET", "DELETE", "POST", "PATCH", "PUT")][ValidateNotNullOrEmpty()]
        [string]$Method,
        [Parameter(Mandatory = $false, ValueFromPipeline = [boolean]$true, ValueFromPipelineByPropertyName = [boolean]$true)]
        [string]$JsonBody,
        [Parameter(Mandatory = $false, ValueFromPipeline = [boolean]$true, ValueFromPipelineByPropertyName = [boolean]$true)]
        [switch]$NoJsonBody,
        [Parameter(Mandatory = $false)]
        [string]$Secret,
        [Parameter(Mandatory = $false, ValueFromPipeline = [boolean]$true, ValueFromPipelineByPropertyName = [boolean]$true)]
        [string]$RunbookUsername,
        [Parameter(Mandatory = $false, ValueFromPipeline = [boolean]$true, ValueFromPipelineByPropertyName = [boolean]$true)]
        [switch]$UseMSI,
        [Parameter(Mandatory = $false, ValueFromPipeline = [boolean]$true, ValueFromPipelineByPropertyName = [boolean]$true)]
        [string]$AccessToken
    )
    
    begin {
       
        $global:Results = [System.Collections.ArrayList]::new()
        #Var checks necessary here, if user enters CTRL + C during the API Call (s), The end block won't intiliaze to the (dispose) cleanup method call

        $VarCheck = [System.Collections.Generic.List[object]]($ChildHash, $SplatArgs) 
        foreach ($var in $VarCheck) {
            if (-not ([string]::IsNullOrEmpty($var))) {
                $ChildHash.Clear()
                $SplatArgs.Clear()
            }
        }
        #Param validation to ensure the correct switch or string input object params are being passed into the function 
        if (-not $PSCmdlet.MyInvocation.BoundParameters["AccessToken"] -and
           (-not $PSCmdlet.MyInvocation.BoundParameters["RunbookUsername"] -and
           (-not $PSCmdlet.MyInvocation.BoundParameters["Secret"] -and
           (-not $PSCmdlet.MyInvocation.BoundParameters["UseMSI"])))) {
            
            throw "You must include at least one of the following parameters: -Secret, -RunbookUserName, -AccessToken, -UseMSI"
        }
        
        #Switch statement to extract the input parameters being used, follow by additional param validation before extracting bearer token
        switch ($PSCmdlet.MyInvocation.BoundParameters.Keys) {

            "UseMSI" {
                if ($PSCmdlet.MyInvocation.BoundParameters.Keys.Contains("Secret") -or
                   ($PSCmdlet.MyInvocation.BoundParameters.Keys.Contains("RunbookUsername") -or
                   ($PSCmdlet.MyInvocation.BoundParameters.Keys.Contains("AccessToken") -or
                   ($PSCmdlet.MyInvocation.BoundParameters.Keys.Contains("ClientID") -or
                   ($PSCmdlet.MyInvocation.BoundParameters.Keys.Contains("TenantName")))))) {
                    throw "You must ONLY use the -UseMSI, -GraphURL, -Method Parameters when using the -UseMSI Parameter"
                }
                else {
                    [string](Get-BearerToken -UseMSI) #This is a nested function that runs from the 'AzureSecrets' Module (required module in this modules Manifest file)
                }
            }

            "Secret" {
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("RunbookUsername") -or
                   ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("AccessToken"))) {
         
                    throw "You must not include the -AccessToken, -RunbookUsername, Parameters when using the -Secret Parameter"
                }
                elseif ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("ClientID") -and
                    $PSCmdlet.MyInvocation.BoundParameters.ContainsKey("TenantName")) {
         
                    $BearerToken = Get-BearerToken -ClientID $ClientID -TenantName $TenantName -Secret $Secret
                }
                else {
                    throw "You must include the -ClientID and -TenantName Parameters when using the -Secret Parameter"
                }
            }
           
            "RunbookUsername" {
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Secret") -or
                   ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("AccessToken"))) {
         
                    throw "You must not include the -AccessToken Or -Secret Parameters when using the -RunbookUsername Parameter"
                }
                elseif ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("ClientID") -and
                    $PSCmdlet.MyInvocation.BoundParameters.ContainsKey("TenantName")) {
         
                    $BearerToken = Get-BearerToken -ClientID $ClientID -TenantName $TenantName -RunbookUsername $RunbookUsername
                }
                else {
                    throw "You must include the -ClientID and -TenantName Parameters when using the -RunbookUsername Parameter"
                }
               
            }
            "AccessToken" { 
                if (-not $PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Secret") -and 
                   (-not $PSCmdlet.MyInvocation.BoundParameters.ContainsKey("RunbookUserName") -and
                   (-not $PSCmdlet.MyInvocation.BoundParameters.ContainsKey("ClientID") -and 
                   (-not $PSCmdlet.MyInvocation.BoundParameters.ContainsKey("TenantName"))))) {
                    
                    $BearerToken = $AccessToken
                }
                else {
                    throw "You must not include the -Secret or -RunbookUserName or -ClientID Parameters when using the -AccessToken Parameter"
                }
            }
        }
    }
    process {

        #Depending on the Input string object passed to the -Method parameter, we will perform different logic for different API Requests
        switch ($PSCmdlet.MyInvocation.BoundParameters["Method"]) {

            "DELETE" {

                [hashtable]$SplatArgs = [System.Collections.Specialized.OrderedDictionary]::new()
                [hashtable]$ChildHash = [System.Collections.Specialized.OrderedDictionary]::new()

                $ChildHash.Add('Authorization', "Bearer $($BearerToken)")
                $SplatArgs.Add('Uri', [string]$GraphURL)
                $SplatArgs.Add('Headers', $ChildHash)
                $SplatArgs.Add('Method', [string]$Method)

                try {
                    Invoke-RestMethod @SplatArgs 
                }
                catch [System.Exception] {
                    throw $global:Error[0].Exception.Message
                }
            }
            "GET" {
                   
                [hashtable]$SplatArgs = [System.Collections.Specialized.OrderedDictionary]::new()
                [hashtable]$ChildHash = [System.Collections.Specialized.OrderedDictionary]::new()

                [hashtable]$ChildHash.Add('Authorization', "Bearer $($BearerToken)")
                [hashtable]$SplatArgs.Add('Uri', [string]$GraphURL)
                [hashtable]$SplatArgs.Add('Headers', $ChildHash)
                [hashtable]$SplatArgs.Add('Method', [string]$Method)

                try {
                    do {
                        [array]$GraphResponse = Invoke-RestMethod @SplatArgs 
                        foreach ($Response in $GraphResponse.Value) {
                            [void]$Results.Add($Response)
                        }
                        $SplatArgs["Uri"] = $GraphResponse."@odata.nextLink"
                    } while ($SplatArgs["Uri"])
                    #Can't do a return statement here, or the end block will NOT return
                    $Results

                    #if object doesn't have property value, check if null and add URL back to URI Key
                    if ([string]::IsNullOrEmpty($Results)) {
                        $SplatArgs["Uri"] = $GraphURL
                        Invoke-RestMethod @SplatArgs
                    }
                }
                catch [System.Exception] {
                    throw $global:Error[0].Exception.Message
                }
            }
            "POST" {
                if (-not ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("JsonBody") -or
                   ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("NoJsonBody")))) {
  
                    throw "You must include the -Jsonbody or -NoJsonBody parameter when using the POST Method in the -Method Parameter"
                }

                [hashtable]$SplatArgs = [System.Collections.Specialized.OrderedDictionary]::new()
                [hashtable]$ChildHash = [System.Collections.Specialized.OrderedDictionary]::new()

                [hashtable]$ChildHash.Add('Authorization', "Bearer $($BearerToken)")
                [hashtable]$SplatArgs.Add('Uri', [string]$GraphURL)
                [hashtable]$SplatArgs.Add('Headers', $ChildHash)
                [hashtable]$SplatArgs.Add('Method', [string]$Method)
                [hashtable]$SplatArgs.Add('ContentType', [string]'application/json')
                [hashtable]$SplatArgs.Add('Body', $JsonBody)

                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("NoJsonBody")) {
                    $SplatArgs.Remove('Body')
                    $SplatArgs.Remove('ContentType')
                }
                try {
                    Invoke-RestMethod @SplatArgs 
                }
                catch [System.Exception] {
                    throw $Global:Error[0].Exception.Message
                }  
            }
            "PUT" {
                if (-not ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("JsonBody"))) {
                    throw "You must include the -JSON body parameter when using the PUT Method in the -Method Parameter"
                }

                [hashtable]$SplatArgs = [System.Collections.Specialized.OrderedDictionary]::new()
                [hashtable]$ChildHash = [System.Collections.Specialized.OrderedDictionary]::new()

                [hashtable]$ChildHash.Add('Authorization', "Bearer $($BearerToken)")
                [hashtable]$SplatArgs.Add('Uri', [string]$GraphURL)
                [hashtable]$SplatArgs.Add('Headers', $ChildHash)
                [hashtable]$SplatArgs.Add('Method', [string]$Method)
                [hashtable]$SplatArgs.Add('ContentType', [string]'application/json')
                [hashtable]$SplatArgs.Add('Body', $JsonBody)

                try {
                    Invoke-RestMethod @SplatArgs 
                }
                catch [System.Exception] {
                    throw $global:Error[0].Exception.Message
                }
            }
            "PATCH" {
                if (-not ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("JsonBody"))) {
                    throw "You must include the -JSON body parameter when using the PATCH Method in the -Method Parameter"
                }

                [hashtable]$SplatArgs = [System.Collections.Specialized.OrderedDictionary]::new()
                [hashtable]$ChildHash = [System.Collections.Specialized.OrderedDictionary]::new()

                [hashtable]$ChildHash.Add('Authorization', "Bearer $($BearerToken)")
                [hashtable]$SplatArgs.Add('Uri', [string]$GraphURL)
                [hashtable]$SplatArgs.Add('Headers', $ChildHash)
                [hashtable]$SplatArgs.Add('Method', [string]$Method)
                [hashtable]$SplatArgs.Add('ContentType', [string]'application/json')
                [hashtable]$SplatArgs.Add('Body', $JsonBody)

                try {
                    Invoke-RestMethod @SplatArgs 
                }
                catch [System.Exception] {
                    throw $Global:Error.Exception.Message
                }
            } 
        }
    }
    end {
        #Purge the dictionary (dispose), this will ONLY purge is CTRL + C was not entered during the API Calls within the switch statement
        $ChildHash.Clear()
        $SplatArgs.Clear()
    }
}

