# Definir las rutas de los ejecutables y el archivo de entrada
$exrheaderPath = "C:\Portable\EXR_tools\OpenEXR\exrheader.exe"
$oiiotoolPath = "C:\Portable\EXR_tools\Oiio\oiiotool.exe"
$inputExr = "C:\Portable\EXR_tools\test.exr"
$outputDir = "C:\Portable\EXR_tools\output"

# Crear el directorio de salida si no existe
if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# Función para obtener los nombres de los canales
function Get-ChannelNames {
    & $exrheaderPath $inputExr | 
        Select-String -Pattern "^\s+(\w+)" | 
        ForEach-Object { $_.Matches.Groups[1].Value } | 
        Where-Object { $_ -notmatch '^[ARGB]$' } | 
        ForEach-Object { $_.Split('.')[0] } | 
        Select-Object -Unique
}

# Obtener los nombres de los canales
$channels = Get-ChannelNames

# Función para agrupar canales con numeración consecutiva
function Group-Channels {
    param($channels)
    $groups = @{}
    foreach ($channel in $channels) {
        $baseName = $channel -replace '\d+$'
        if (-not $groups.ContainsKey($baseName)) {
            $groups[$baseName] = @()
        }
        $groups[$baseName] += $channel
    }
    return $groups
}

# Agrupar los canales
$groupedChannels = Group-Channels $channels

# Exportar canales
foreach ($group in $groupedChannels.GetEnumerator()) {
    $baseName = $group.Key
    $channelList = $group.Value | ForEach-Object { "$_.R,$_.G,$_.B,$_.A" }
    $channelString = $channelList -join ","

    # Exportar con compresión ZIP
    $outputFileZip = Join-Path $outputDir "test_${baseName}_combined-zip.exr"
    & $oiiotoolPath $inputExr --ch $channelString --compression zip -o $outputFileZip
    Write-Host "Exported: $outputFileZip (with ZIP compression)"

    # Exportar con compresión DWAA
    $outputFileDwaa = Join-Path $outputDir "test_${baseName}_combined-dwaa.exr"
    & $oiiotoolPath $inputExr --ch $channelString --compression dwaa -o $outputFileDwaa
    Write-Host "Exported: $outputFileDwaa (with DWAA compression)"

    # Exportar con compresión Pxr24
    $outputFilePxr24 = Join-Path $outputDir "test_${baseName}_combined-pxr24.exr"
    & $oiiotoolPath $inputExr --ch $channelString --compression Pxr24 -o $outputFilePxr24
    Write-Host "Exported: $outputFilePxr24 (with Pxr24 compression)"
}

Write-Host "All channels exported successfully with ZIP, DWAA, and Pxr24 compression."
