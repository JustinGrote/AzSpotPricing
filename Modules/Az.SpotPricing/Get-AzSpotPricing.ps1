#requires -version 7
function Get-AzSpotPricing {
    [CmdletBinding()]
    param (
        #Which Regions to query. Default is to query all regions
        [String[]]$Region,
        #Which VM sizes to query. Default is to query all sizes
        [String[]]$Size,
        #Your username and password to log in
        [PSCredential]$Credential,
        #The subscription ID to inquire, defaults to your current Azure Context's ID.
        [ValidateNotNullOrEmpty()][String]$SubscriptionId = (Get-AzContext).subscription.id
    )

    if (-not $SCRIPT:azPortalKey.AccessToken -or $SCRIPT:azPortalKey.Expires -lt [DateTime]::Now) {
        if (-not $Credential) {
            $Credential = Get-Credential -Message 'Enter your Azure AD credentials. This only works with non-MFA non-Personal Azure AD accounts.'
        }
        $SCRIPT:azPortalKey = Get-AzPortalToken -Credential $Credential
    }

    #Load the hardware map. This gets cached into the module
    if (-not $SCRIPT:hardwareMap) {
        $SCRIPT:hardwareMap = Get-AzSpotPricingHardwareMap
    }

    
    $optimizedHardwareMap = Optimize-AzSpotPricingHardwareMap -HardwareMap $hardwareMap -Region $Region -Size $Size
    
    $SpecsCostsBody = Convert-HardwareMapToSpecRequest -hardwareMap $optimizedHardwareMap -SubscriptionId $SubscriptionId
    
    $GetSpecsCostsParams = @{
        URI            = 'https://s2.billing.ext.azure.com/api/Billing/Subscription/GetSpecsCosts?SpotPricing=true'
        Method         = 'POST'
        Authentication = 'Bearer'
        ContentType    = 'application/json'
        Token          = $SCRIPT:azPortalKey.AccessToken
        Body           = $SpecsCostsBody
    }
    
    $getSpecsCostsResult = Invoke-RestMethod @GetSpecsCostsParams -ErrorAction Stop
    $getSpecsCostsResult.costs | Select-Object -Property @(
        @{
            Name       = 'Size'
            Expression = { $_.id.split('|')[0] }
        },
        @{
            Name       = 'Location'
            Expression = { $_.id.split('|')[1] }
        },
        'amount',
        'currencyCode'
    )

}

function Convert-HardwareMapToSpecRequest {
    param (
        [Parameter(Mandatory)][HashTable]$hardwareMap,
        [Parameter(Mandatory)][String]$SubscriptionId
    )

    $SpecRequest = @{
        specType             = 'Microsoft_Azure_Compute'
        subscriptionId       = $SubscriptionId
        specResourceSets     = @()
        specsToAllowZeroCost = @()
    }

    $SpecRequest.specResourceSets = @(
        foreach ($azLocation in $hardwareMap.keys) {
            foreach ($azSize in $hardwareMap[$azLocation].keys) {
                $sizeId = $azSize,$azLocation -join '|'
                @{
                    id         = $sizeId
                    thirdParty = @()
                    firstParty = @(
                        @{
                            id         = $sizeId
                            quantity   = 1
                            resourceId = $hardwareMap[$azLocation].$azSize
                        }
                    )
                }
            }
        }
    )
    #Allow all specs to return zero values to avoid errors
    $SpecRequest.specsToAllowZeroCost = @($SpecRequest.specResourceSets.id)

    $SpecRequest | ConvertTo-Json -Depth 9
}