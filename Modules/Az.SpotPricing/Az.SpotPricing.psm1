Get-Item $PSScriptRoot\*.ps1 | Foreach-Object {
    . $PSItem
}