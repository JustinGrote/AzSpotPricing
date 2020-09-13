function Get-AzPortalCostAPIToken {
    param (
        [Parameter(Mandatory)][PSCredential]$Credential,
        $URI = "https://portal.azure.com/"

    )

    $driver = Start-SeChrome -Headless -EnablePerformanceLogging -StartUrl $URI -Quiet

    #Enter Username
    Send-SeKeys -Element (Find-SeElement -Driver $driver -Id 'i0116' -Wait) -Keys $Credential.UserName 
    Invoke-SeClick -Element (Find-SeElement -Driver $driver -id 'idSIButton9' -Wait)

    #Enter Password
    Send-SeKeys -Element (Find-SeElement -Driver $driver -Id 'i0118' -Wait) -Keys $Credential.GetNetworkCredential().Password
    #TODO: Find the proper element to wait for
    Start-Sleep 1
    Invoke-SeClick -Element (Find-SeElement -Driver $driver -id 'idSIButton9' -Wait)

    #Flush logs up to this point
    $null = $driver.Manage().Logs.GetLog('performance')

    #Skip stay signed in box
    Invoke-SeClick -Element (Find-SeElement -Driver $driver -id 'idBtn_Back' -Wait)
    Start-Sleep 1

    #This finds the first query that uses the special token we want
    $bearerTokenLog = $driver.Manage().Logs.GetLog('performance') 
    | Where-Object Message -like '*fx.Services.Tenants.getTenants*'
    | Select-Object -First 1

    $token = ($bearerTokenLog.message | ConvertFrom-Json).message.params.request.headers.authorization -replace 'Bearer ',''
    | ConvertTo-SecureString -AsPlainText

    return $token
}