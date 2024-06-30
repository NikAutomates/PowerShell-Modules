$Commands = @(Get-ChildItem -Path $PSScriptRoot\functions\*.ps1)
foreach ($Function in @($Commands)) {
    . $Function.FullName
}
    