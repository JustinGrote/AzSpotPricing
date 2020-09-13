function Get-AzSpotPricingHardwareMap {
    param(
        $JSPath = "$PSScriptRoot\HardwareMaps"
    )
    $hardwareMap = @{}
    $hardwareMapRegex = '^.+?HardwareMap.(?<location>\w+).+?t.hardwareMap=.+?t.hardwareMap=(?<hardwaremap>.+)\}\)\)$'
    
    (Get-ChildItem $JSPath).foreach{
        if (-not ((Get-Content -Raw -Path $PSItem.fullname) -match $hardwaremapRegex)) {throw "$PSItem is not a valid hardware map javascript"}
        $hardwareMap[$matches.location] = (ConvertFrom-Json -AsHashTable $matches.hardwareMap)
    }

    return $hardwareMap
}
