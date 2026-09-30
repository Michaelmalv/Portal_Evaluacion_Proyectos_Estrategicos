Add-Type -AssemblyName System.IO.Compression.FileSystem

$excelPath = (Resolve-Path "Matriz Total de Soterramientos.xlsx").Path
$zip = [System.IO.Compression.ZipFile]::OpenRead($excelPath)

function Get-EntryText($entryName) {
    $entry = $zip.Entries | Where-Object { $_.FullName -eq $entryName }
    if ($null -eq $entry) { return $null }
    $stream = $entry.Open()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
    $text = $reader.ReadToEnd()
    $reader.Dispose()
    $stream.Dispose()
    return $text
}

$ssXmlText = Get-EntryText "xl/sharedStrings.xml"
$ssXml = [xml]$ssXmlText
$ss = @()
if ($ssXmlText) {
    foreach ($si in $ssXml.sst.si) {
        $t = $si.InnerText
        $ss += $t
    }
}

$sheet1XmlText = Get-EntryText "xl/worksheets/sheet1.xml"
$sheet1Xml = [xml]$sheet1XmlText

function Get-ColIndex($cellRef) {
    $colLetters = ($cellRef -replace '[0-9]', '')
    $col = 0
    foreach ($char in [char[]]$colLetters) {
        $col = ($col * 26) + ([int]$char - [int][char]'A' + 1)
    }
    return $col - 1
}

function Clean-Money($val) {
    if ($null -eq $val -or $val -eq "") { return $null }
    $s = [string]$val
    $s = $s.Replace('$', '').Replace('USD', '').Trim()
    if ($s -match '^\s*$') { return $null }
    if ($s.Contains('.') -and $s.Contains(',')) {
        if ($s.IndexOf('.') -lt $s.IndexOf(',')) {
            $s = $s.Replace('.', '').Replace(',', '.')
        } else {
            $s = $s.Replace(',', '')
        }
    } elseif ($s.Contains(',')) {
        $s = $s.Replace(',', '.')
    }
    try {
        return [double]$s
    } catch {
        return $null
    }
}

function Clean-Float($val) {
    if ($null -eq $val -or $val -eq "") { return $null }
    $s = [string]$val
    $s = $s.Replace(',', '.').Trim()
    try {
        return [double]$s
    } catch {
        return $null
    }
}

function Format-ProjectName($rawName, $nro) {
    $n = $rawName.Trim()
    if ($nro -eq 50) { return "Av. 6 de Diciembre" }
    if ($nro -eq 69) { return "Av. 6 de Diciembre (Planificado)" }
    if ($n -eq "PROYECTO QUICENTRO NORTE") { return "Quicentro Norte" }
    if ($n -eq "PROYECTO GRAN MARCELINO") { return "Gran Marcelino" }
    if ($n -eq "PROYECTO SENNA") { return "Senna" }
    if ($n -eq "PROYECTO EPIQ") { return "Epiq" }
    if ($n -like "*GUAL*") { return "Puente Gual" + [char]0x00F3 }
    if ($n -like "*CONDE IV*") { return "Puente Conde IV" }
    if ($n -like "*SAN PATRICIO*") { return "PUAE San Patricio" }
    if ($n -like "*MIRADOR*") { return "Puente Peatonal El Mirador" }
    if ($n -like "*SENDERO*CALDER*") { return "Sendero Seguro Calder" + [char]0x00F3 + "n" }
    if ($n -like "*COL*N*") { return "Sendero Seguro Col" + [char]0x00F3 + "n" }
    if ($n -like "*PUEBLO BLANCO*") { return "Puente Peatonal Pueblo Blanco" }
    if ($n -like "*M*LAGA*") { return "Hacienda M" + [char]0x00E1 + "laga - OPA" }
    if ($n -like "*PRADERA II*") { return "Pradera II" }
    if ($n -like "*MONJAS*") { return "Puente R" + [char]0x00ED + "o Monjas" }
    if ($n -like "*6 DE DICIEMBRE*") { return "Av. 6 de Diciembre" }
    if ($n -like "*PATRIA*") { return "Av. Patria" }
    if ($n -like "*RODRIGO DE CH*") { return "Av. Rodrigo de Ch" + [char]0x00E1 + "vez" }
    if ($n -like "*SAN BLAS*") { return "San Blas" }
    if ($n -eq "KOEN") { return "Koen" }
    if ($n -like "*SANTA M*NICA*") { return "PUAE Santa M" + [char]0x00F3 + "nica" }
    if ($n -like "*PLAZA CALDER*") { return "Plaza Calder" + [char]0x00F3 + "n" }
    if ($n -like "*PAMPITE*") { return "Pampite Artz" }
    if ($n -like "*EL INCA*") { return "Av. El Inca" }
    if ($n -like "*AJAV*") { return "Av. Ajav" + [char]0x00ED }
    if ($n -like "*CUSUBAMBA*") { return "Av. Cusubamba" }
    if ($n -like "*PRENSA*") { return "Av. La Prensa" }
    if ($n -eq "BICENTENARIO") { return "Bicentenario" }
    if ($n -like "*QUITOPIA*") { return "Quitop" + [char]0x00ED + "a La Y" }
    if ($n -like "*CIUDAD BICENTENARIO*") { return "Puente Ciudad Bicentenario" }
    if ($n -like "*HUGO ORTIZ*") { return "Av. Teniente Hugo Ortiz" }
    if ($n -like "*MA*OSCA*") { return "Av. Ma" + [char]0x00F1 + "osca" }
    if ($n -like "*GASCA*") { return "Av. La Gasca" }
    if ($n -like "*12 DE OCTUBRE*") { return "Av. 12 de Octubre" }
    if ($n -like "*GARC*S*") { return "Calle Jorge Garc" + [char]0x00E9 + "s" }
    if ($n -like "*ALONSO DE ANGULO*") { return "Av. Mariscal Sucre y Alonso de Angulo" }
    if ($n -like "*AM*RICA*") { return "Av. Am" + [char]0x00E9 + "rica" }
    if ($n -like "*GALO PLAZA*") { return "Av. Galo Plaza Lasso" }
    
    return (Get-Culture).TextInfo.ToTitleCase($n.ToLower().Replace('proyecto ', ''))
}

function Format-Parroquia($p) {
    if (-not $p) { return $null }
    $clean = $p.Trim()
    if ($clean -like "*INAQUITO*" -or $clean -like "*I*aquito*") { return "I" + [char]0x00F1 + "aquito" }
    if ($clean -like "*TUMBACO*") { return "Tumbaco" }
    if ($clean -like "*CUMBAY*") { return "Cumbay" + [char]0x00E1 }
    if ($clean -like "*CALDER*N*") { return "Calder" + [char]0x00F3 + "n" }
    if ($clean -like "*CENTRO HIST*") { return "Centro Hist" + [char]0x00F3 + "rico" }
    if ($clean -like "*CONCEPCI*") { return "La Concepci" + [char]0x00F3 + "n" }
    if ($clean -like "*MARISCAL*") { return "Mariscal Sucre" }
    if ($clean -like "*MAGDALENA*") { return "La Magdalena" }
    if ($clean -like "*RUMIPAMBA*") { return "Rumipamba" }
    if ($clean -like "*COMIT*") { return "Comit" + [char]0x00E9 + " del Pueblo" }
    if ($clean -like "*CHILLOGALLO*") { return "Chillogallo" }
    if ($clean -like "*SOLANDA*") { return "Solanda" }
    if ($clean -like "*SAN JUAN*") { return "San Juan" }
    if ($clean -like "*ITCHIMB*") { return "Itchimb" + [char]0x00ED + "a" }
    if ($clean -like "*COTOCOLLAO*") { return "Cotocollao" }
    if ($clean -like "*KENNEDY*") { return "Kennedy" }
    if ($clean -like "*BELISARIO QUEVEDO*") { return "Belisario Quevedo" }
    return (Get-Culture).TextInfo.ToTitleCase($clean.ToLower())
}

$soterramientoList = @()

foreach ($row in $sheet1Xml.worksheet.sheetData.row) {
    $rIdx = [int]$row.r
    if ($rIdx -lt 9) { continue }
    
    $rowCells = @{}
    foreach ($c in $row.c) {
        $cRef = $c.r
        $cIdx = Get-ColIndex $cRef
        $val = ""
        if ($c.t -eq "s") {
            $sIdx = [int]$c.v
            if ($sIdx -lt $ss.Count) {
                $val = $ss[$sIdx]
            }
        } elseif ($null -ne $c.v) {
            $val = $c.v
        }
        $rowCells[$cIdx] = $val
    }
    
    $nroVal = $rowCells[1]
    if (-not $nroVal -or -not ($nroVal -match '^\d+$')) { continue }
    $nro = [int]$nroVal
    
    $anoRaw = [string]$rowCells[2]
    $nombreRaw = [string]$rowCells[3]
    
    if (-not $nombreRaw -or $nombreRaw.Trim() -eq "") { continue }
    
    # Filter: Ano >= 2023 or Nro >= 36
    $is2023Plus = ($anoRaw -match '2023|2024|2025|2026|2027') -or ($nro -ge 36)
    if (-not $is2023Plus) { continue }
    
    $nombreClean = Format-ProjectName $nombreRaw $nro
    $parroquiaClean = Format-Parroquia $rowCells[10]
    $viaClean = if ($rowCells[11]) { $rowCells[11].Trim() } else { $nombreClean }
    
    $inversionTelecom = Clean-Money $rowCells[19]
    $montoTotal = Clean-Money $rowCells[16]
    $inversionCivil = Clean-Money $rowCells[17]
    
    $kmVal = Clean-Float $rowCells[7]
    $latInit = Clean-Float $rowCells[12]
    $lngInit = Clean-Float $rowCells[13]
    $latFinal = Clean-Float $rowCells[14]
    $lngFinal = Clean-Float $rowCells[15]
    
    $estado = if ($rowCells[5]) { $rowCells[5].Trim().ToUpper() } else { "PLANIFICADO" }
    $tipo = if ($rowCells[6]) { $rowCells[6].Trim().ToUpper() } else { "REGENERACI" + [char]0x00D3 + "N URBANA" }
    $ejecutor = if ($rowCells[4]) { $rowCells[4].Trim().ToUpper() } else { "EPMMOP" }
    $fuente = if ($rowCells[18]) { $rowCells[18].Trim() } else { "Inversi" + [char]0x00F3 + "n P" + [char]0x00FA + "blica" }
    $obs = if ($rowCells[27]) { $rowCells[27].Trim() } else { $null }
    
    $anoDisplay = if ($anoRaw -match '^\d+$') { [int]$anoRaw } else { $anoRaw.Trim() }
    
    $record = [ordered]@{
        id = "sot_$nro"
        nro = $nro
        nombre = $nombreClean
        nombre_original = $nombreRaw.Trim()
        ano = $anoDisplay
        ejecutor = $ejecutor
        estado = $estado
        tipo_proyecto = $tipo
        kilometros = $kmVal
        provincia = "PICHINCHA"
        canton = "QUITO"
        parroquia = $parroquiaClean
        via_principal = $viaClean
        coordenadas_inicial = [ordered]@{
            lat = $latInit
            lng = $lngInit
        }
        coordenadas_final = [ordered]@{
            lat = $latFinal
            lng = $lngFinal
        }
        fuente_financiamiento = $fuente
        inversion_telecom = $inversionTelecom
        monto_total = $montoTotal
        inversion_obra_civil = $inversionCivil
        observaciones = $obs
    }
    
    $soterramientoList += $record
}

Write-Output "Parsed $($soterramientoList.Count) projects (>= 2023)."

# Save to web/src/lib/soterramiento.json
$jsonContent = $soterramientoList | ConvertTo-Json -Depth 5
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Resolve-Path "web\src\lib\soterramiento.json").Path, $jsonContent, $utf8NoBom)

Write-Output "Successfully updated web/src/lib/soterramiento.json!"
$zip.Dispose()
