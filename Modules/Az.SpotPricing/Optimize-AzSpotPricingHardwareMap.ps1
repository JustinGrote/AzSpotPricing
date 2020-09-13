function Optimize-AzSpotPricingHardwareMap {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][HashTable]$HardwareMap,
        [String[]]$Region,
        [String[]]$Size
    )

    #Fast short circuit
    if (-not $Region -and -not $Size) {return $HardwareMap}

    if (-not $Region) {$Region = $HardwareMap.Keys}

    $optimizedHardwareMap = @{}

    foreach ($RegionItem in $Region) {
        $RegionSizes = if ($Size) {
            $hardwareMap[$RegionItem].Keys | Where-Object {$PSItem -in $Size}
        } else {
            $hardwareMap[$RegionItem].Keys
        }
        $regionSizeMap = @{}
        $regionSizes.foreach{
            $regionSizeMap[$PSItem] = $HardwareMap[$RegionItem].$PSItem
        }
        $optimizedHardwareMap[$RegionItem] = $regionSizeMap
    }

    return $optimizedHardwareMap
}