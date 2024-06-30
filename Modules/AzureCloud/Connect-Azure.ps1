 <#
.AUTHOR
    Nik Chikersal
.SYNOPSIS
    This function is used to Connect to Azure using the Connect-AzAccount Cmdlet. 
    The function can be used to check if an existing connection exists, or automatically connect.
    In Addition, the function validates the account connecting to Azure, and the machine the function is being run on.
.EXAMPLE
    Connect-Azure -CheckIfConnected
    This example shows how to check if an existing connection exists, and if not, connect to Azure

    Connect-Azure
    This example shows how to connect to Azure without checking if an existing connection exists
.NOTES
Validate set within function is being worked on to include entity sets, rather than just the ones listed below.
#>


Function Connect-Azure {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [switch]$CheckIfConnected
    )

    if ($CheckIfConnected) {
        if (![string]::IsNullOrEmpty((Get-AzContext))) {
            #Already connected, do nothing - just a check
            ""
        }
        elseif ([string]::IsNullOrEmpty(((Get-AzContext)))) {
            if ((whoami /upn) -match "@(.+)$") {
                $Question = Read-Host "Would you like to use $(whoami /upn) to Connect to Azure. `
                Type 'Y' to continue or 'N' to specify a different account"
                while ($Question -ne "Y" -and $Question -ne "N") {
                    Write-Warning "Invalid Input"
                    $Question = Read-Host "Would you like to use $(whoami /upn) to Connect to Azure. `
                    Type 'Y' to continue or 'N' to specify a different account"
                }
                switch ($Question) {
                    "Y" {
                        [void](Connect-AzAccount -AccountId (Whoami /upn))
                        if (![string]::IsNullOrEmpty((Get-AzContext))) {
                            [PSCustomObject]@{
                                Account           = (Get-AzContext).Account.ID
                                AzureSubscription = (Get-AzContext).Subscription.Name
                                ConnectedEnv      = (Get-AzContext).Environment.Name
                                UsingModule       = (Get-InstalledModule -Name azureSecrets).Name + " " + "(" + (Get-InstalledModule -Name AzureSecrets).Version  + ")"
                            }
                            Write-Output ""
                            Show-AvailableCommands
                        }
                    }
                    "N" {
                        [void](Connect-AzAccount)
                        if (![string]::IsNullOrEmpty((Get-AzContext))) {
                            [PSCustomObject]@{
                                Account           = (Get-AzContext).Account.ID
                                AzureSubscription = (Get-AzContext).Subscription.Name
                                ConnectedEnv      = (Get-AzContext).Environment.Name
                                UsingModule       = (Get-InstalledModule -Name azureSecrets).Name + " " + "(" + (Get-InstalledModule -Name AzureSecrets).Version  + ")"
                            }
                            Write-Output ""
                            Show-AvailableCommands
                        }
                    }
                }
            }
            Else {
                Write-Warning "$(Hostname) is not joined to Azure AD or AD to connect with a signed in UPN"
                Write-Output "Connecting to Azure with last signed in account"
                Start-Sleep -Seconds 3 ; Clear-Host
                [void](Connect-AzAccount)
                if (![string]::IsNullOrEmpty((Get-AzContext))) {
                    [PSCustomObject]@{
                        Account           = (Get-AzContext).Account.ID
                        AzureSubscription = (Get-AzContext).Subscription.Name
                        ConnectedEnv      = (Get-AzContext).Environment.Name
                        UsingModule       = (Get-InstalledModule -Name azureSecrets).Name + " " + "(" + (Get-InstalledModule -Name AzureSecrets).Version  + ")"
                    }
                    Write-Output ""
                    Show-AvailableCommands
                }
            }
        }
    }
    elseif (!$CheckIfConnected) {
        if ((whoami /upn) -match "@(.+)$") {
            $Question = Read-Host "Would you like to use $(whoami /upn) to Connect to Azure. `
            Type 'Y' to continue or 'N' to specify a different account"
            while ($Question -ne "Y" -and $Question -ne "N") {
                Write-Warning "Invalid Input"
                $Question = Read-Host "Would you like to use $(whoami /upn) to Connect to Azure. `
                Type 'Y' to continue or 'N' to specify a different account"
            }
            switch ($Question) {
                "Y" {
                    [void](Connect-AzAccount -AccountId (Whoami /upn))
                    if (![string]::IsNullOrEmpty((Get-AzContext))) {
                        Clear-Host
                        [PSCustomObject]@{
                            Account           = (Get-AzContext).Account.ID
                            AzureSubscription = (Get-AzContext).Subscription.Name
                            ConnectedEnv      = (Get-AzContext).Environment.Name
                            UsingModule       = (Get-InstalledModule -Name azureSecrets).Name + " " + "(" + (Get-InstalledModule -Name AzureSecrets).Version  + ")"
                        }
                        Write-Output ""
                        Show-AvailableCommands
                    }
                }
                "N" {
                    [void](Connect-AzAccount)
                    if (![string]::IsNullOrEmpty((Get-AzContext))) {
                        Clear-Host
                        [PSCustomObject]@{
                            Account           = (Get-AzContext).Account.ID
                            AzureSubscription = (Get-AzContext).Subscription.Name
                            ConnectedEnv      = (Get-AzContext).Environment.Name
                            UsingModule       = (Get-InstalledModule -Name azureSecrets).Name + " " + "(" + (Get-InstalledModule -Name AzureSecrets).Version  + ")"
                        }
                        Write-Output ""
                        Show-AvailableCommands
                    }
                }
            }
        }
        Else {
            Write-Warning "$(Hostname) is not joined to Azure AD or AD to connect with a signed in UPN"
            Write-Output "Connecting to Azure with last signed in account"
            Start-Sleep -Seconds 3 ; Clear-Host
            [void](Connect-AzAccount)
            if (![string]::IsNullOrEmpty((Get-AzContext))) {
                [PSCustomObject]@{
                    Account           = (Get-AzContext).Account.ID
                    AzureSubscription = (Get-AzContext).Subscription.Name
                    ConnectedEnv      = (Get-AzContext).Environment.Name
                    UsingModule       = (Get-InstalledModule -Name azureSecrets).Name + " " + "(" + (Get-InstalledModule -Name AzureSecrets).Version  + ")"
                }
                Write-Output ""
                Show-AvailableCommands
            }
        }
    }
}
