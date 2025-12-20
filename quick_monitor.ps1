# Monitoreo rápido de procesos con historial - ejecutar en otra ventana

Write-Host "=== MONITOR RAPIDO DE PROCESOS CON HISTORIAL ===" -ForegroundColor Yellow
Write-Host "Ejecutar en otra ventana mientras corre EXR_to_DPX.ps1" -ForegroundColor Cyan
Write-Host "Las alertas quedan registradas permanentemente" -ForegroundColor Green
Write-Host ""

# Historial de alertas persistente
$script:alertHistory = @()
$script:lastIinfoCount = 0
$script:lastOiiotoolCount = 0
$script:sessionStart = Get-Date

while ($true) {
    Clear-Host

    # Header con tiempo de sesión
    $sessionDuration = [math]::Round(((Get-Date) - $script:sessionStart).TotalMinutes, 1)
    Write-Host "$(Get-Date -Format 'HH:mm:ss') - PROCESOS (Sesión: ${sessionDuration}min):" -ForegroundColor Yellow
    Write-Host ""

    # Contar procesos
    $powershell = (Get-Process -Name "powershell" -ErrorAction SilentlyContinue).Count
    $iinfo = (Get-Process -Name "iinfo" -ErrorAction SilentlyContinue).Count
    $oiiotool = (Get-Process -Name "oiiotool" -ErrorAction SilentlyContinue).Count

    Write-Host "PowerShell: $powershell" -ForegroundColor $(if ($powershell -gt 5) { "Red" } elseif ($powershell -gt 2) { "Yellow" } else { "Green" })
    Write-Host "iinfo: $iinfo" -ForegroundColor $(if ($iinfo -gt 0) { "Red" } else { "Green" })
    Write-Host "oiiotool: $oiiotool" -ForegroundColor $(if ($oiiotool -gt 0) { "Red" } else { "Green" })

    # Memoria del proceso principal
    $mainProc = Get-Process -Id $PID -ErrorAction SilentlyContinue
    if ($mainProc) {
        $memoryMB = [math]::Round($mainProc.WorkingSet / 1MB, 1)
        Write-Host "Memoria (nuestro proceso): ${memoryMB}MB" -ForegroundColor Cyan
    }

    Write-Host ""

    # ALERTAS ACTUALES
    $currentAlerts = @()

    if ($iinfo -gt 0) {
        Write-Host "[ALERTA ACTIVA] Procesos iinfo activos!" -ForegroundColor Red
        $currentAlerts += "iinfo"

        $iinfoDetails = Get-Process -Name "iinfo" -ErrorAction SilentlyContinue
        foreach ($proc in $iinfoDetails) {
            $age = ""
            if ($proc.StartTime) {
                $age = [math]::Round(((Get-Date) - $proc.StartTime).TotalSeconds, 0)
            }
            Write-Host "  PID $($proc.Id): ${age}s" -ForegroundColor Red
        }
    }

    if ($oiiotool -gt 0) {
        Write-Host "[ALERTA ACTIVA] Procesos oiiotool activos!" -ForegroundColor Red
        $currentAlerts += "oiiotool"

        $oiiotoolDetails = Get-Process -Name "oiiotool" -ErrorAction SilentlyContinue
        foreach ($proc in $oiiotoolDetails) {
            $age = ""
            if ($proc.StartTime) {
                $age = [math]::Round(((Get-Date) - $proc.StartTime).TotalSeconds, 0)
            }
            Write-Host "  PID $($proc.Id): ${age}s" -ForegroundColor Red
        }
    }

    # Registrar nuevas alertas en el historial
    $currentTime = Get-Date

    # Detectar aparición de iinfo
    if ($iinfo -gt 0 -and $script:lastIinfoCount -eq 0) {
        $alert = @{
            Type    = "iinfo"
            Event   = "APARECIO"
            Time    = $currentTime
            Count   = $iinfo
            Message = "Procesos iinfo detectados ($iinfo activos)"
        }
        $script:alertHistory += $alert
        Write-Host "[REGISTRADO] Nueva alerta iinfo - $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Magenta
    }
    # Detectar desaparición de iinfo
    elseif ($iinfo -eq 0 -and $script:lastIinfoCount -gt 0) {
        $alert = @{
            Type    = "iinfo"
            Event   = "DESAPARECIO"
            Time    = $currentTime
            Count   = 0
            Message = "Procesos iinfo desaparecieron (estuvieron activos ${script:lastIinfoCount})"
        }
        $script:alertHistory += $alert
        Write-Host "[RESUELTO] Alerta iinfo resuelta - $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
    }

    # Detectar aparición de oiiotool
    if ($oiiotool -gt 0 -and $script:lastOiiotoolCount -eq 0) {
        $alert = @{
            Type    = "oiiotool"
            Event   = "APARECIO"
            Time    = $currentTime
            Count   = $oiiotool
            Message = "Procesos oiiotool detectados ($oiiotool activos)"
        }
        $script:alertHistory += $alert
        Write-Host "[REGISTRADO] Nueva alerta oiiotool - $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Magenta
    }
    # Detectar desaparición de oiiotool
    elseif ($oiiotool -eq 0 -and $script:lastOiiotoolCount -gt 0) {
        $alert = @{
            Type    = "oiiotool"
            Event   = "DESAPARECIO"
            Time    = $currentTime
            Count   = 0
            Message = "Procesos oiiotool desaparecieron (estuvieron activos ${script:lastOiiotoolCount})"
        }
        $script:alertHistory += $alert
        Write-Host "[RESUELTO] Alerta oiiotool resuelta - $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
    }

    # Actualizar contadores para siguiente iteración
    $script:lastIinfoCount = $iinfo
    $script:lastOiiotoolCount = $oiiotool

    # HISTORIAL DE ALERTAS (últimas 10)
    if ($script:alertHistory.Count -gt 0) {
        Write-Host ""
        Write-Host "HISTORIAL DE ALERTAS (últimas 10):" -ForegroundColor Yellow
        Write-Host ("-" * 60) -ForegroundColor DarkGray

        $recentAlerts = $script:alertHistory | Select-Object -Last 10
        foreach ($alert in $recentAlerts) {
            $timeStr = $alert.Time.ToString("HH:mm:ss")
            $icon = switch ($alert.Event) {
                "APARECIO" { "[+]" }
                "DESAPARECIO" { "[-]" }
                default { "[?]" }
            }
            $color = switch ($alert.Type) {
                "iinfo" { "Red" }
                "oiiotool" { "Yellow" }
                default { "Gray" }
            }

            Write-Host "$icon $timeStr $($alert.Type.ToUpper()) $($alert.Event) - $($alert.Message)" -ForegroundColor $color
        }

        # Estadísticas
        $totalAlerts = $script:alertHistory.Count
        $activeAlerts = $script:alertHistory | Where-Object { $_.Event -eq "APARECIO" -and -not ($script:alertHistory | Where-Object { $_.Type -eq $_.Type -and $_.Event -eq "DESAPARECIO" -and $_.Time -gt $_.Time }) } | Measure-Object | Select-Object -ExpandProperty Count

        Write-Host ""
        Write-Host "Total alertas: $totalAlerts | Activas: $activeAlerts" -ForegroundColor Cyan
    }

    Start-Sleep -Seconds 3
}