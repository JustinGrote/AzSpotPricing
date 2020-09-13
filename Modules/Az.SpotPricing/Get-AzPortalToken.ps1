function Get-AzPortalToken {
    param (
        [Parameter(Mandatory)][PSCredential]$Credential
    )
    $progresspreference = 'silentlycontinue'

    $headers = @{
        'Sec-Fetch-Dest' = 'script'
        'Sec-Fetch-Site' = 'same-origin'
        'Sec-Fetch-Mode' = 'no-cors'
        'Referer'        = 'https://portal.azure.com'
    }

    $body = @{
        'feature.usemsallogin'            = 'true'
        'feature.argsubscriptions'        = 'true'
        'feature.showservicehealthalerts' = 'true'
        'feature.iriscore'                = 'true'
        'feature.prefetchtokens'          = 'true'
        'idpc'                            = 0
    }

    #Ask the Azure Portal to redirect to Azure AD
    $response = Invoke-WebRequest -Uri 'https://portal.azure.com/signin/idpRedirect.js/' -Body $body -Headers $headers -SessionVariable 'PortalLoginSession'
    $authorizeUriRegex = '(' + [Regex]::Escape('https://login.microsoftonline.com/organizations/oauth2/v2.0/authorize') + '.+?)"'
    if ($response.content -notmatch $authorizeUriRegex) { throw 'Azure Portal did not provide an authorization URI. This is probably a bug' }

    $authorizeUri = $matches[1]

    #Get the authorization config from Azure AD
    $configResponse = Invoke-WebRequest -Uri $authorizeUri -WebSession $PortalLoginSession
    $configJsonRegex = 'Config=(.+?});'
    if ($configResponse.content -notmatch $configJsonRegex) { throw 'Unable to retrieve the Login Configuration from the authorization request. This is probably a bug.' }
    $authorizationConfig = $matches[1] | ConvertFrom-Json

    #Login to login.microsoftonline.com
    $loginBody = @{
        login            = $Credential.userName
        loginFmt         = $Credential.userName
        i13              = '0'
        type             = '11'
        LoginOptions     = '3'
        passwd           = $Credential.GetNetworkCredential().Password
        ps               = '2'
        flowToken        = $authorizationConfig.sFT
        canary           = $authorizationConfig.canary
        ctx              = $authorizationConfig.sCtx
        NewUser          = '1'
        fspost           = '0'
        i21              = '0'
        CookieDisclosure = '1'
        IsFidoSupported  = '1'
        hpgrequestid     = "$(New-Guid)"
    }

    $loginResponse = Invoke-WebRequest -Method POST -Uri 'https://login.microsoftonline.com/common/login' -Body $loginBody -WebSession $PortalLoginSession
    if ($loginResponse.content -notmatch $configJsonRegex) { throw 'Unable to retrieve the Login Configuration from the authorization request. This is probably a bug.' }
    $loginConfig = $matches[1] | ConvertFrom-Json

    #Click KMSI and get postback info for the portal
    $kmsiBody = @{
        LoginOptions = 28
        type         = 28
        ctx          = $loginConfig.sCtx
        hpgrequestid = "$(New-Guid)"
        flowToken    = $loginConfig.sFT
        canary       = $loginConfig.canary
        i19          = 2507
    }
    $kmsiResponse = Invoke-WebRequest -Method POST -Uri 'https://login.microsoftonline.com/kmsi' -Body $kmsiBody -WebSession $PortalLoginSession
    $azurePortalToken = ($kmsiresponse.InputFields | Where-Object name -EQ 'id_token').value
    if (-not $azurePortalToken) {throw 'There was a problem with the login and we did not get an Azure Portal Token'}

    #Postback the login info to the portal
    $portalSignInBody = @{}
    $kmsiResponse.InputFields | where name | foreach {
        $portalSignInBody.($PSItem.Name) = $PSItem.value
    }

    $portalAuthResponse = Invoke-WebRequest -Uri "https://portal.azure.com/signin/index/" -Method POST -Body $portalSignInBody -WebSession $PortalLoginSession
    $portalAuthInfoRegex = 'MsPortalImpl.setBootstrapStateAndRedirect\(".+?",\n({"oAuthToken".+?}}),\n'
    if ($portalAuthResponse.content -notmatch $portalAuthInfoRegex) {throw 'Postback to the Azure Portal Failed. This is probably a bug.'}
    $portalAuthInfo = $matches[1] | ConvertFrom-Json

    return @{
        AccessToken = $portalAuthInfo.oAuthToken.authHeader -replace '^Bearer ','' | ConvertTo-SecureString -AsPlainText
        RefreshToken = $portalAuthInfo.oAuthToken.refreshToken | ConvertTo-SecureString -AsPlainText
        Expires = [DateTime]::Now.AddMilliseconds($portalAuthInfo.oAuthToken.expiresInMs)
    }
}