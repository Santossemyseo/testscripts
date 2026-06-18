#Requires -Version 5.1
<#
.SYNOPSIS
  Forensic-Investigation-V1.6.ps1
  Recoleccion forense segura para archivo/carpeta con foco en DRP, Hyper-V y Azure.

.DESCRIPTION
  Version mejorada de V1.5. Mantiene ejecucion de solo lectura sobre el objetivo y agrega:
  - Parametro -TargetPath para ejecucion interactiva o automatizada.
  - Parametro -BasePath para no depender exclusivamente de C:\DRP\reporte.
  - Mapeo correcto de propiedades Hyper-V hacia el resultado final.
  - Normalizacion de rutas para correlacionar discos Hyper-V.
  - Analisis avanzado Hyper-V: VMMS, Worker, checkpoints, merges, AVHDX, tipo de VHD y relacion con VM.
  - Inventarios CSV/JSON con rutas de salida registradas en el resultado.
  - Manifest SHA256 de los reportes generados para cadena de custodia.
  - Limites configurables de eventos y antiguedad de logs.

.NOTES
  Requiere permisos de Administrador para varias validaciones.
  No modifica auditorias, politicas ni archivos del objetivo.
#>

[CmdletBinding()]
param(
    [string]$TargetPath,
    [string]$BasePath = 'C:\DRP\reporte',
    [int]$MaxSecurityEventsToScan = 5000,
    [int]$MaxSecurityMatches = 100,
    [int]$MaxHyperVEventsToScan = 5000,
    [int]$EventLookbackYears = 2,
    [switch]$NoSelfElevate
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-SelfElevation {
    if ($NoSelfElevate -or (Test-IsAdministrator)) { return }

    Write-Host 'Elevando permisos...' -ForegroundColor Yellow
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($TargetPath) { $argList += @('-TargetPath', "`"$TargetPath`"") }
    if ($BasePath) { $argList += @('-BasePath', "`"$BasePath`"") }
    $argList += @('-MaxSecurityEventsToScan', $MaxSecurityEventsToScan)
    $argList += @('-MaxSecurityMatches', $MaxSecurityMatches)
    $argList += @('-MaxHyperVEventsToScan', $MaxHyperVEventsToScan)
    $argList += @('-EventLookbackYears', $EventLookbackYears)
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
    exit
}

function Initialize-ReportFolders {
    param([Parameter(Mandatory=$true)][string]$RootPath)

    foreach ($subFolder in @('logs', 'evidencia', 'csv', 'json', 'resumen', 'manifest')) {
        $path = Join-Path $RootPath $subFolder
        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
}

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host ('=' * 60) -ForegroundColor Cyan
    Write-Host (' {0}' -f $Title) -ForegroundColor Cyan
    Write-Host ('=' * 60) -ForegroundColor Cyan
}

function Get-SafePathInfo {
    param([Parameter(Mandatory=$true)][string]$InputPath)

    try {
        $resolved = Resolve-Path -LiteralPath $InputPath -ErrorAction Stop
        return Get-Item -LiteralPath $resolved.Path -Force -ErrorAction Stop
    } catch {
        return $null
    }
}

function ConvertTo-NormalizedPath {
    param([string]$InputPath)
    if ([string]::IsNullOrWhiteSpace($InputPath)) { return $null }

    try {
        return [IO.Path]::GetFullPath($InputPath).TrimEnd('\').ToUpperInvariant()
    } catch {
        return $InputPath.TrimEnd('\').ToUpperInvariant()
    }
}

function Get-ReadableFileSystemAclAudit {
    param([Parameter(Mandatory=$true)][string]$InputPath)

    try {
        $audit = (Get-Acl -LiteralPath $InputPath).Audit
        if ($null -eq $audit) { return @() }
        return @($audit)
    } catch {
        return @()
    }
}

function Get-FileHashSafe {
    param([Parameter(Mandatory=$true)][string]$InputPath)

    try {
        return (Get-FileHash -LiteralPath $InputPath -Algorithm SHA256 -ErrorAction Stop).Hash
    } catch {
        return $null
    }
}

function Get-AuditPolicyText {
    try { return (auditpol /get /subcategory:'File System' 2>&1 | Out-String) }
    catch { return 'No disponible' }
}

function Get-USNStatus {
    try {
        fsutil usn queryjournal C: *> $null
        if ($LASTEXITCODE -eq 0) { return 'ACTIVO' }
        return 'NO DISPONIBLE'
    } catch {
        return 'ERROR'
    }
}

function Get-SysmonStatus {
    try {
        $svc = Get-Service -Name *sysmon* -ErrorAction SilentlyContinue
        if ($svc) { return 'INSTALADO' }
        return 'NO INSTALADO'
    } catch {
        return 'ERROR'
    }
}

function Get-LimitedSecurityEvents {
    param(
        [Parameter(Mandatory=$true)][string]$InputPath,
        [int]$MaxEventsToScan = 5000,
        [int]$MaxMatches = 100
    )

    $leaf = Split-Path -Path $InputPath -Leaf
    if ([string]::IsNullOrWhiteSpace($leaf)) { return @() }

    try {
        $events = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = @(4656,4660,4663) } -MaxEvents $MaxEventsToScan -ErrorAction SilentlyContinue
        return @($events |
            Where-Object { $_.Message -like "*$leaf*" -or $_.Message -like "*$InputPath*" } |
            Select-Object -First $MaxMatches TimeCreated, Id, ProviderName, LevelDisplayName, Message)
    } catch {
        return @()
    }
}

function Get-HyperVModuleAvailable {
    try { return [bool](Get-Module -ListAvailable -Name Hyper-V) }
    catch { return $false }
}

function Get-HyperVLogEvents {
    param(
        [Parameter(Mandatory=$true)][string]$LogName,
        [Parameter(Mandatory=$true)][string[]]$SearchTerms,
        [int]$LookbackYears = 2,
        [int]$MaxEventsToScan = 5000
    )

    try {
        $events = Get-WinEvent -FilterHashtable @{
            LogName   = $LogName
            StartTime = (Get-Date).AddYears(-1 * $LookbackYears)
        } -MaxEvents $MaxEventsToScan -ErrorAction SilentlyContinue

        return @($events | Where-Object {
            $message = $_.Message
            @($SearchTerms | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $message -match [regex]::Escape($_) }).Count -gt 0
        })
    } catch {
        return @()
    }
}

function Get-HyperVVMMSEvents {
    param(
        [Parameter(Mandatory=$true)][string[]]$SearchTerms,
        [int]$LookbackYears = 2,
        [int]$MaxEventsToScan = 5000
    )

    return Get-HyperVLogEvents -LogName 'Microsoft-Windows-Hyper-V-VMMS-Admin' -SearchTerms $SearchTerms -LookbackYears $LookbackYears -MaxEventsToScan $MaxEventsToScan
}

function Get-HyperVWorkerEvents {
    param(
        [Parameter(Mandatory=$true)][string[]]$SearchTerms,
        [int]$LookbackYears = 2,
        [int]$MaxEventsToScan = 5000
    )

    return Get-HyperVLogEvents -LogName 'Microsoft-Windows-Hyper-V-Worker-Admin' -SearchTerms $SearchTerms -LookbackYears $LookbackYears -MaxEventsToScan $MaxEventsToScan
}

function Get-TargetHyperVInfo {
    param(
        [Parameter(Mandatory=$true)][string]$InputPath,
        [Parameter(Mandatory=$true)][object]$Item,
        [Parameter(Mandatory=$true)][string]$ReportRoot,
        [Parameter(Mandatory=$true)][string]$TimeStamp,
        [int]$LookbackYears = 2,
        [int]$MaxEventsToScan = 5000
    )

    $result = [ordered]@{
        TargetIsHyperV = $false; HyperV_DiskPath = $null; HyperV_VhdType = $null; HyperV_FileSizeGB = $null
        HyperV_MaxSizeGB = $null; HyperV_ParentPath = $null; HyperV_Fragmentation = $null; HyperV_VMName = $null
        HyperV_VMId = $null; HyperV_VMState = $null; HyperV_VMCreationTime = $null; HyperV_CheckpointType = $null; HyperV_SnapshotCount = $null
        HyperV_Exports = 0; HyperV_MergeStart = 0; HyperV_MergeEnd = 0; HyperV_Checkpoints = 0
        HyperV_CheckpointDeletes = 0; HyperV_VMMSLogName = 'Microsoft-Windows-Hyper-V-VMMS-Admin'; HyperV_VMMSEventCount = 0
        HyperV_WorkerLogName = 'Microsoft-Windows-Hyper-V-Worker-Admin'; HyperV_WorkerEventCount = 0; HyperV_WorkerTimelineFile = $null
        HyperV_AVHDXCount = 0; HyperV_AVHDXInventoryFile = $null; HyperV_TimelineFile = $null; HyperV_Error = $null
        HyperV_DynamicToFixedSignal = $null
    }

    if ($Item.Extension -notin @('.vhd', '.vhdx', '.avhdx')) { return [pscustomobject]$result }
    if (-not (Get-HyperVModuleAvailable)) {
        $result.HyperV_Error = 'Modulo Hyper-V no disponible'
        return [pscustomobject]$result
    }

    try {
        Import-Module Hyper-V -ErrorAction SilentlyContinue | Out-Null
        $vhd = Get-VHD -Path $InputPath -ErrorAction Stop
        $result.TargetIsHyperV = $true
        $result.HyperV_DiskPath = $vhd.Path
        $result.HyperV_VhdType = $vhd.VhdType
        $result.HyperV_FileSizeGB = [math]::Round(($vhd.FileSize / 1GB), 2)
        $result.HyperV_MaxSizeGB = [math]::Round(($vhd.Size / 1GB), 2)
        $result.HyperV_ParentPath = $vhd.ParentPath
        $result.HyperV_Fragmentation = $vhd.FragmentationPercentage

        if ($vhd.VhdType -eq 'Dynamic') { $result.HyperV_DynamicToFixedSignal = 'ORIGEN_DYNAMIC' }
        elseif ($vhd.VhdType -eq 'Fixed') { $result.HyperV_DynamicToFixedSignal = 'DESTINO_FIXED' }

        $normalizedTarget = ConvertTo-NormalizedPath -InputPath $InputPath
        $vmMatch = @(Get-VMHardDiskDrive -ErrorAction SilentlyContinue | Where-Object {
            (ConvertTo-NormalizedPath -InputPath $_.Path) -eq $normalizedTarget
        } | Select-Object -First 1)

        if ($vmMatch.Count -gt 0) {
            $vmName = $vmMatch[0].VMName
            $result.HyperV_VMName = $vmName

            try {
                $vm = Get-VM -Name $vmName -ErrorAction Stop
                $result.HyperV_VMId = $vm.Id
                $result.HyperV_VMState = $vm.State.ToString()
                $result.HyperV_VMCreationTime = $vm.CreationTime
                $result.HyperV_CheckpointType = $vm.CheckpointType.ToString()
            } catch { }

            $snapshots = @(Get-VMSnapshot -VMName $vmName -ErrorAction SilentlyContinue)
            $result.HyperV_SnapshotCount = $snapshots.Count

            $searchTerms = @($vmName, $result.HyperV_VMId, [IO.Path]::GetFileName($InputPath), $InputPath)
            $vmmsEvents = Get-HyperVVMMSEvents -SearchTerms $searchTerms -LookbackYears $LookbackYears -MaxEventsToScan $MaxEventsToScan
            $workerEvents = Get-HyperVWorkerEvents -SearchTerms $searchTerms -LookbackYears $LookbackYears -MaxEventsToScan $MaxEventsToScan
            $result.HyperV_VMMSEventCount = $vmmsEvents.Count
            $result.HyperV_WorkerEventCount = $workerEvents.Count
            $result.HyperV_Exports = @($vmmsEvents | Where-Object { $_.Id -eq 18303 }).Count
            $result.HyperV_MergeStart = @($vmmsEvents | Where-Object { $_.Id -eq 19070 }).Count
            $result.HyperV_MergeEnd = @($vmmsEvents | Where-Object { $_.Id -eq 19080 }).Count
            $result.HyperV_Checkpoints = @($vmmsEvents | Where-Object { $_.Id -in 14050,14070,14075,14076 }).Count
            $result.HyperV_CheckpointDeletes = @($vmmsEvents | Where-Object { $_.Id -in 14051,14071,14077 }).Count

            if ($vmmsEvents.Count -gt 0) {
                $timelineFile = Join-Path $ReportRoot ("csv\HyperVTimeline_{0}.csv" -f $TimeStamp)
                $vmmsEvents | Select-Object TimeCreated, Id, LevelDisplayName, Message | Sort-Object TimeCreated |
                    Export-Csv -Path $timelineFile -NoTypeInformation -Encoding UTF8
                $result.HyperV_TimelineFile = $timelineFile
            }

            if ($workerEvents.Count -gt 0) {
                $workerTimelineFile = Join-Path $ReportRoot ("csv\HyperVWorkerTimeline_{0}.csv" -f $TimeStamp)
                $workerEvents | Select-Object TimeCreated, Id, LevelDisplayName, Message | Sort-Object TimeCreated |
                    Export-Csv -Path $workerTimelineFile -NoTypeInformation -Encoding UTF8
                $result.HyperV_WorkerTimelineFile = $workerTimelineFile
            }
        }

        $folder = Split-Path -Path $InputPath -Parent
        if (Test-Path -LiteralPath $folder) {
            $avhdxFiles = @(Get-ChildItem -LiteralPath $folder -Recurse -File -Filter *.avhdx -ErrorAction SilentlyContinue)
            $result.HyperV_AVHDXCount = $avhdxFiles.Count
            if ($avhdxFiles.Count -gt 0) {
                $avhdxInventoryFile = Join-Path $ReportRoot ("csv\HyperVAVHDXInventory_{0}.csv" -f $TimeStamp)
                $avhdxFiles | Select-Object FullName, Length, CreationTime, LastWriteTime, LastAccessTime |
                    Export-Csv -Path $avhdxInventoryFile -NoTypeInformation -Encoding UTF8
                $result.HyperV_AVHDXInventoryFile = $avhdxInventoryFile
            }
        }
    } catch {
        $result.HyperV_Error = $_.Exception.Message
    }

    return [pscustomobject]$result
}

function Get-DRPScriptInventory {
    param([Parameter(Mandatory=$true)][string]$RootPath)

    $items = @()
    foreach ($pattern in @('crea*.ps1', 'conver*.ps1', 'cargue*.ps1', 'orquestador*.ps1', '*drp*.ps1', '*azcopy*.ps1')) {
        $items += @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue)
    }
    return @($items | Sort-Object FullName -Unique)
}

function Get-AzCopyLogInventory {
    $roots = @()
    if ($env:USERPROFILE) { $roots += (Join-Path $env:USERPROFILE '.azcopy') }
    if ($env:ProgramData) { $roots += (Join-Path $env:ProgramData 'AzCopy') }

    $results = @()
    foreach ($root in ($roots | Sort-Object -Unique)) {
        if (Test-Path -LiteralPath $root) {
            $results += @(Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue)
        }
    }
    return @($results | Sort-Object FullName -Unique)
}

function Get-VHDInventory {
    param([Parameter(Mandatory=$true)][string]$RootPath)

    $files = @()
    foreach ($pattern in @('*.vhd', '*.vhdx', '*.avhdx')) {
        $files += @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue)
    }

    return @($files | Sort-Object FullName -Unique | ForEach-Object {
        $vhdType = $null; $size = $null; $fileSize = $null; $parentPath = $null; $fragmentation = $null
        try {
            if (Get-HyperVModuleAvailable) {
                Import-Module Hyper-V -ErrorAction SilentlyContinue | Out-Null
                $v = Get-VHD -Path $_.FullName -ErrorAction Stop
                $vhdType = $v.VhdType; $size = $v.Size; $fileSize = $v.FileSize; $parentPath = $v.ParentPath; $fragmentation = $v.FragmentationPercentage
            }
        } catch { }

        [pscustomobject]@{
            FullName = $_.FullName; Name = $_.Name; Length = $_.Length; CreationTime = $_.CreationTime; LastWriteTime = $_.LastWriteTime
            VhdType = $vhdType; SizeBytes = $size; FileSizeBytes = $fileSize; ParentPath = $parentPath; Fragmentation = $fragmentation; StorageType = $vhdType
        }
    })
}

function Get-ForensicScore {
    param([Parameter(Mandatory=$true)][object]$Result)

    $score = 10
    if ($Result.USNJournal -eq 'ACTIVO') { $score += 15 }
    if ($Result.Sysmon -eq 'INSTALADO') { $score += 30 }
    if ($Result.NTFSAudit -eq 'CONFIGURADA') { $score += 25 }
    if ($Result.SecurityEventsFound -gt 0) { $score += 20 }

    $capability = if ($score -lt 30) { 'BAJA' } elseif ($score -lt 70) { 'MEDIA' } else { 'ALTA' }
    return [pscustomobject]@{ Score = $score; Capability = $capability }
}

function Get-ManagerSummary {
    param([Parameter(Mandatory=$true)][object]$Result)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('=================================================')
    $lines.Add('RESUMEN EJECUTIVO')
    $lines.Add('=================================================')
    $lines.Add('')
    foreach ($name in @('TargetPath', 'TargetType', 'Name', 'CreationTime', 'LastWriteTime', 'LastAccessTime', 'USNJournal', 'Sysmon', 'AuditPolicyState', 'NTFSAudit', 'SecurityEventsFound', 'ForensicScore', 'Capability')) {
        $lines.Add(('{0}: {1}' -f $name, $Result.$name))
    }
    if ($Result.TargetType -eq 'File') {
        $lines.Add("SHA256: $($Result.SHA256)")
        $lines.Add("Tamano bytes: $($Result.SizeBytes)")
    }
    if ($Result.TargetIsHyperV -or $Result.HyperV_VMName -or $Result.HyperV_VhdType) {
        $lines.Add('')
        $lines.Add('=================================================')
        $lines.Add('ANALISIS HYPER-V')
        $lines.Add('=================================================')
        $lines.Add('')
        foreach ($name in @(
            'HyperV_VMName', 'HyperV_VMId', 'HyperV_VMState', 'HyperV_VMCreationTime', 'HyperV_CheckpointType',
            'HyperV_VhdType', 'HyperV_FileSizeGB', 'HyperV_MaxSizeGB', 'HyperV_ParentPath', 'HyperV_Fragmentation',
            'HyperV_SnapshotCount', 'HyperV_AVHDXCount', 'HyperV_AVHDXInventoryFile',
            'HyperV_VMMSLogName', 'HyperV_VMMSEventCount', 'HyperV_Exports', 'HyperV_MergeStart', 'HyperV_MergeEnd',
            'HyperV_Checkpoints', 'HyperV_CheckpointDeletes', 'HyperV_TimelineFile',
            'HyperV_WorkerLogName', 'HyperV_WorkerEventCount', 'HyperV_WorkerTimelineFile',
            'HyperV_DynamicToFixedSignal', 'HyperV_Error'
        )) {
            $lines.Add(('{0}: {1}' -f $name, $Result.$name))
        }
    }
    $lines.Add('')
    $lines.Add('CONCLUSION')
    $lines.Add('Reporte de solo lectura basado en evidencia disponible al momento de ejecucion.')
    return ($lines -join [Environment]::NewLine)
}

function Export-Manifest {
    param(
        [Parameter(Mandatory=$true)][string[]]$Files,
        [Parameter(Mandatory=$true)][string]$ManifestPath
    )

    $manifest = foreach ($file in $Files) {
        if (Test-Path -LiteralPath $file) {
            [pscustomobject]@{
                Path = $file
                SHA256 = Get-FileHashSafe -InputPath $file
                Length = (Get-Item -LiteralPath $file).Length
                CreatedUtc = (Get-Item -LiteralPath $file).CreationTimeUtc
            }
        }
    }
    $manifest | Export-Csv -Path $ManifestPath -NoTypeInformation -Encoding UTF8
}

Start-SelfElevation
Initialize-ReportFolders -RootPath $BasePath

$TimeStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$TranscriptFile = Join-Path $BasePath ("logs\forensic_{0}.log" -f $TimeStamp)
Start-Transcript -Path $TranscriptFile -Force | Out-Null

try {
    Clear-Host
    Write-Section -Title 'FORENSIC FILE INVESTIGATION V1.6'
    Write-Host 'Lectura segura. Evidencia minima suficiente. Impacto minimo en produccion.' -ForegroundColor DarkGray

    if ([string]::IsNullOrWhiteSpace($TargetPath)) {
        $TargetPath = Read-Host 'Ingrese ruta de archivo o carpeta'
    }
    if ([string]::IsNullOrWhiteSpace($TargetPath)) { throw 'No se ingreso una ruta.' }

    $item = Get-SafePathInfo -InputPath $TargetPath
    if (-not $item) { throw "Ruta no encontrada o no accesible: $TargetPath" }

    $targetType = if ($item.PSIsContainer) { 'Folder' } else { 'File' }
    $auditPolicy = Get-AuditPolicyText
    $auditPolicyState = if ($auditPolicy -match 'Sin auditor|No Auditing') { 'NO CONFIGURADA' } elseif ($auditPolicy -match 'Correcto y Error|Success and Failure') { 'CONFIGURADA' } elseif ($auditPolicy -match 'Correcto|Success') { 'PARCIAL' } else { 'DESCONOCIDA' }

    $result = [ordered]@{
        ExecutionDate = Get-Date; ComputerName = $env:COMPUTERNAME; User = $env:USERNAME; PowerShell = $PSVersionTable.PSVersion.ToString()
        TargetPath = $item.FullName; TargetType = $targetType; Name = $item.Name; FullName = $item.FullName
        CreationTime = $item.CreationTime; LastWriteTime = $item.LastWriteTime; LastAccessTime = $item.LastAccessTime
        SizeBytes = $null; SHA256 = $null; AuditPolicy = $auditPolicy; AuditPolicyState = $auditPolicyState
        NTFSAudit = 'NO DISPONIBLE'; USNJournal = Get-USNStatus; Sysmon = Get-SysmonStatus; SecurityEventsFound = 0
        TargetIsHyperV = $false; HyperV_DiskPath = $null; HyperV_VhdType = $null; HyperV_FileSizeGB = $null; HyperV_MaxSizeGB = $null
        HyperV_ParentPath = $null; HyperV_Fragmentation = $null; HyperV_VMName = $null; HyperV_VMId = $null; HyperV_VMState = $null; HyperV_VMCreationTime = $null
        HyperV_CheckpointType = $null; HyperV_SnapshotCount = $null; HyperV_Exports = 0; HyperV_MergeStart = 0; HyperV_MergeEnd = 0
        HyperV_Checkpoints = 0; HyperV_CheckpointDeletes = 0; HyperV_VMMSLogName = 'Microsoft-Windows-Hyper-V-VMMS-Admin'; HyperV_VMMSEventCount = 0
        HyperV_WorkerLogName = 'Microsoft-Windows-Hyper-V-Worker-Admin'; HyperV_WorkerEventCount = 0; HyperV_WorkerTimelineFile = $null
        HyperV_AVHDXCount = 0; HyperV_AVHDXInventoryFile = $null; HyperV_TimelineFile = $null; HyperV_Error = $null
        HyperV_DynamicToFixedSignal = $null; DRP_ScriptCount = 0; AzCopyLogCount = 0; HistoricalVhdCount = 0
        HyperVRelatedExportCount = 0; HyperVRelatedMergeCount = 0; FixedVhdCount = 0; DynamicVhdCount = 0
        ForensicScore = 0; Capability = 'DESCONOCIDA'; OutputFiles = @(); Notes = @()
    }

    if ($targetType -eq 'File') {
        $result.SizeBytes = $item.Length
        $result.SHA256 = Get-FileHashSafe -InputPath $item.FullName
    }

    $auditEntries = Get-ReadableFileSystemAclAudit -InputPath $item.FullName
    $result.NTFSAudit = if ($auditEntries.Count -gt 0) { 'CONFIGURADA' } else { 'NO CONFIGURADA' }

    $securityEvents = Get-LimitedSecurityEvents -InputPath $item.FullName -MaxEventsToScan $MaxSecurityEventsToScan -MaxMatches $MaxSecurityMatches
    $result.SecurityEventsFound = @($securityEvents).Count

    $hypervInfo = Get-TargetHyperVInfo -InputPath $item.FullName -Item $item -ReportRoot $BasePath -TimeStamp $TimeStamp -LookbackYears $EventLookbackYears -MaxEventsToScan $MaxHyperVEventsToScan
    foreach ($prop in $hypervInfo.PSObject.Properties) { $result[$prop.Name] = $prop.Value }

    $rootForInventory = if ($item.PSIsContainer) { $item.FullName } else { Split-Path -Path $item.FullName -Parent }
    $inventoryRoot = if (Test-Path -LiteralPath 'C:\DRP') { 'C:\DRP' } else { $rootForInventory }

    $drpScripts = @(); $azcopyLogs = @(); $vhdInventory = @()
    if (Test-Path -LiteralPath $inventoryRoot) {
        $drpScripts = Get-DRPScriptInventory -RootPath $inventoryRoot
        $vhdInventory = Get-VHDInventory -RootPath $inventoryRoot
    }
    $azcopyLogs = Get-AzCopyLogInventory

    $result.DRP_ScriptCount = @($drpScripts).Count
    $result.AzCopyLogCount = @($azcopyLogs).Count
    $result.HistoricalVhdCount = @($vhdInventory).Count
    $result.FixedVhdCount = @($vhdInventory | Where-Object { $_.StorageType -eq 'Fixed' }).Count
    $result.DynamicVhdCount = @($vhdInventory | Where-Object { $_.StorageType -eq 'Dynamic' }).Count

    if ($result.DynamicVhdCount -gt 0 -and $result.FixedVhdCount -gt 0) { $result.HyperV_DynamicToFixedSignal = 'POSIBLE_CONVERSION_EN_ENTORNO' }

    $scoreObj = Get-ForensicScore -Result ([pscustomobject]$result)
    $result.ForensicScore = $scoreObj.Score
    $result.Capability = $scoreObj.Capability

    Write-Section -Title 'EXPORTACION DE EVIDENCIA'
    $txtFile = Join-Path $BasePath ("evidencia\evidencia_{0}.txt" -f $TimeStamp)
    $jsonFile = Join-Path $BasePath ("json\resultado_{0}.json" -f $TimeStamp)
    $csvFile = Join-Path $BasePath ("csv\eventos_{0}.csv" -f $TimeStamp)
    $summaryFile = Join-Path $BasePath ("resumen\resumen_ejecutivo_{0}.txt" -f $TimeStamp)
    $manifestFile = Join-Path $BasePath ("manifest\manifest_{0}.csv" -f $TimeStamp)

    $tech = [ordered]@{
        Result = [pscustomobject]$result
        SecurityEvents = $securityEvents
        AuditEntries = $auditEntries
        DRPScripts = $drpScripts | Select-Object FullName, Length, CreationTime, LastWriteTime
        AzCopyLogs = $azcopyLogs | Select-Object FullName, Length, CreationTime, LastWriteTime
        VHDInventory = $vhdInventory
    }
    ($tech | ConvertTo-Json -Depth 8) | Out-File -FilePath $txtFile -Encoding UTF8
    $result | ConvertTo-Json -Depth 8 | Out-File -FilePath $jsonFile -Encoding UTF8
    if ($securityEvents.Count -gt 0) { $securityEvents | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8 }
    if ($drpScripts.Count -gt 0) { $drpScripts | Select-Object FullName, Length, CreationTime, LastWriteTime | Export-Csv -Path (Join-Path $BasePath ("csv\drp_scripts_{0}.csv" -f $TimeStamp)) -NoTypeInformation -Encoding UTF8 }
    if ($azcopyLogs.Count -gt 0) { $azcopyLogs | Select-Object FullName, Length, CreationTime, LastWriteTime | Export-Csv -Path (Join-Path $BasePath ("csv\azcopy_logs_{0}.csv" -f $TimeStamp)) -NoTypeInformation -Encoding UTF8 }
    if ($vhdInventory.Count -gt 0) { $vhdInventory | Export-Csv -Path (Join-Path $BasePath ("csv\vhd_inventory_{0}.csv" -f $TimeStamp)) -NoTypeInformation -Encoding UTF8 }

    Get-ManagerSummary -Result ([pscustomobject]$result) | Out-File -FilePath $summaryFile -Encoding UTF8
    Export-Manifest -Files @($txtFile, $jsonFile, $csvFile, $summaryFile, $TranscriptFile, $result.HyperV_TimelineFile, $result.HyperV_WorkerTimelineFile, $result.HyperV_AVHDXInventoryFile) -ManifestPath $manifestFile

    Write-Section -Title 'RESULTADO'
    Write-Host 'Analisis completado.' -ForegroundColor Green
    Write-Host "Ruta: $($result.TargetPath)"
    Write-Host "Tipo: $($result.TargetType)"
    Write-Host "Capacidad Forense: $($result.ForensicScore)/100"
    Write-Host "Nivel: $($result.Capability)"
    Write-Host "Reportes generados en: $BasePath" -ForegroundColor Yellow
    Write-Host "Manifest: $manifestFile" -ForegroundColor Yellow
} finally {
    try { Stop-Transcript | Out-Null } catch { }
}
