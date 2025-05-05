# ───────────────────────────────────────────
# SETUP SCRIPT PENTRU INSTALARE IMPRIMANTE
# Autor: misonex
# Versiune: 1.0
# Data: 2025-04-29
# ───────────────────────────────────────────

# === INIȚIALIZARE LOGURI ===

# Informații sistem
$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$computerName = $env:COMPUTERNAME
$localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.IPAddress -notmatch '^169\.254|^127\.' -and $_.ValidLifetime -gt 0
} | Select-Object -First 1).IPAddress

if (-not $localIP) {
    $localIP = "IP_Necunoscut"
}

# Cale server log
$serverLogPath = "\\server\pub\path\printer_logs"
$localLogPath = $PSScriptRoot

# Verificăm dacă avem acces la server
if (Test-Path $serverLogPath) {
    $logBasePath = $serverLogPath
    Write-Host "`n * " -NoNewline -BackgroundColor Green -ForegroundColor Black
    Write-Host " Logurile vor fi salvate pe server." -ForegroundColor Green
} else {
    $logBasePath = $localLogPath
    Write-Host "`n * " -NoNewline -BackgroundColor Red -ForegroundColor Black
    Write-Host " Serverul nu este accesibil. Se folosesc loguri locale." -ForegroundColor Yellow
}

# Calea completă pentru log.txt
$logTxtPath = Join-Path -Path $logBasePath -ChildPath ("log_$localIP.txt")
"`n=== LOG INSTALARE IMPRIMANTE - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===`n" | Out-File -FilePath $logTxtPath -Encoding UTF8 -Append

function Log {
    param([string]$text)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] $text" | Out-File -FilePath $logTxtPath -Append -Encoding UTF8
}

# Calea pentru CSV
$csvLogPath = Join-Path -Path $logBasePath -ChildPath "installed_printers.csv"

# Scriere CSV – cu antet dacă fișierul nu există
function Write-CsvLog {
    param (
        [string]$printerIP,
        [string]$printerName,
        [string]$driverName,
        [string]$wasDefault
    )

    $line = [PSCustomObject]@{
        Data            = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        IP_Statie       = $localIP
        Nume_Statie     = $computerName
        IP_Imprimanta   = $printerIP
        Nume_Imprimanta = $printerName
        Driver          = $driverName
        Implicita       = $wasDefault
    }

    $writeHeader = -not (Test-Path $csvLogPath)
    try {
        $line | Export-Csv -Path $csvLogPath -Append -NoTypeInformation -Encoding UTF8 -Force
        if ($writeHeader) {
            Log "Antet CSV scris (fișier nou): $csvLogPath"
        }
    }
    catch {
        Log "Eroare la scrierea în CSV: $_"
        Write-Warning "Eroare la scrierea în CSV. Vezi log.txt"
    }
}

# === DEFINIREA DRIVERELOR ===
$drivers = @{
    "1" = @{
        Title = "HP LaserJet MFP E42540"
        Name = "HP LaserJet E40040 PCL 6 (V3)"
        Inf  = Join-Path -Path $PSScriptRoot -ChildPath "HP_E40040_V3\hpwrd42a_x64.inf"
    }
    "2" = @{
        Title = "HP LaserJet E40040"
        Name = "HP LaserJet E40040 PCL 6 (V3)"
        Inf  = Join-Path -Path $PSScriptRoot -ChildPath "HP_E40040_V3\hpwrd42a_x64.inf"
    }
    "3" = @{
        Title = "HP LaserJet Pro M402"
        Name = "HP LaserJet Pro M402-M403 n-dne PCL-6"
        Inf  = Join-Path -Path $PSScriptRoot -ChildPath "HP_M402DNE\hpcuXP0c.inf"
    }
    "4" = @{
        Title = "HP LaserJet Pro M428"
        Name = "HP LaserJet Pro M428f-M429f PCL-6 (V4)"
        Inf  = Join-Path -Path $PSScriptRoot -ChildPath "HP_M428_V4\hpteC22A4_x64.inf"
    }
    "5" = @{
        Title = "Lexmark MX410"
        Name = "Lexmark MX410"
        Inf  = Join-Path -Path $PSScriptRoot -ChildPath "Lexmark_MX410\cnlb0ma.inf"
    }
    "6" = @{
        Title = "Lexmark MS510 DN"
        Name = "Lexmark MS510 DN"
        Inf  = Join-Path -Path $PSScriptRoot -ChildPath "Lexmark_MS510DN\cnlb0ma.inf"
    }
}

function Install-PrinterDriver {
    param (
        [string]$DriverName,
        [string]$InfFile
    )

    # Verificare dacă driverul este deja instalat
    $existingDriver = Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue

    if ($existingDriver) {
        Write-Host "`n * " -NoNewline -BackgroundColor Green -ForegroundColor Black
        Write-Host " Driverul " -NoNewline -ForegroundColor Yellow
        Write-Host $DriverName -NoNewline -ForegroundColor DarkCyan
        Write-Host " este deja instalat. " -ForegroundColor Yellow
        Write-Host "    Se foloseste fara reinstalare." -ForegroundColor Yellow
        Log "Driver deja instalat: $DriverName"
        return
    }

    try {
        Write-Host "`n * " -NoNewline -BackgroundColor Green -ForegroundColor Black
        Write-Host " Adaugare driver " -NoNewline -ForegroundColor Green
        Write-Host $DriverName -NoNewline -ForegroundColor Cyan
        Write-Host "..." -ForegroundColor Green

        $elapsed = Measure-Command {
            $pnp = & pnputil.exe /add-driver $InfFile /install

            if ("$pnp" -notmatch "added successfully|successfully installed|already imported") {
                throw "Eroare la adăugarea driverului [$DriverName]."
            }
        }

        #Add-PrinterDriver -Name $DriverName -ErrorAction Stop
        Write-Host " OK!" -ForegroundColor Green
        Log ("Driver instalat: $DriverName (durata: {0:N2} secunde)" -f $elapsed.TotalSeconds)
    }
    catch {
        Log "Eroare la instalarea driverului: $DriverName - $_"
        Write-Error $_
        exit 1
    }
}

function IsValidIP {
    param ([string]$ip)

    # Încercăm să separăm IP-ul în 4 octeți
    $parts = $ip -split '\.'
    if ($parts.Length -ne 4) { return $false }

    foreach ($part in $parts) {
        if (-not ($part -match '^\d{1,3}$')) { return $false }
        if ([int]$part -lt 0 -or [int]$part -gt 255) { return $false }
    }

    return $true
}

do {
    $elapsedPrinter = Measure-Command {
        do {
            Write-Host "`nSelecteaza tipul de imprimanta:" -ForegroundColor Cyan
            $drivers.GetEnumerator() | Sort-Object {[int]$_.Key} | ForEach-Object {
                Write-Host "$($_.Key)) $($_.Value.Title)"
            }
            $driverChoice = Read-Host "`nIntrodu numarul corespunzator (1-6)"
        
            if ($drivers.ContainsKey($driverChoice)) {
                break
            }
            
            Write-Host "Selectie invalida. Incearca din nou..." -ForegroundColor Red
            Log "Selectie invalida de driver: $driverChoice"
        } while ($true)

        $DriverName = $drivers[$driverChoice].Name
        $InfFile = $drivers[$driverChoice].Inf

        Install-PrinterDriver -DriverName $DriverName -InfFile $InfFile

        $PrinterName = Read-Host "`nIntrodu numele imprimantei"
        do {
            $PrinterIP = Read-Host "`nIntrodu IP-ul imprimantei"
            if (IsValidIP $PrinterIP) { break }
            Write-Host "Format IP invalid. Te rog sa introduci un IP valid (ex: 10.200.1.100)." -ForegroundColor Red
            Log "IP invalid introdus: $PrinterIP"
        } while ($true)
        $WasDefault = "Nu"

        try {
            Add-PrinterPort -Name $PrinterIP -PrinterHostAddress $PrinterIP -ErrorAction Stop
            Write-Host "  > Portul " -NoNewline -ForegroundColor Yellow
            Write-Host $PrinterIP -NoNewline -ForegroundColor DarkCyan
            Write-Host " a fost creat." -ForegroundColor Yellow
        }
        catch {
            Write-Host "  > Portul exista deja sau a aparut o eroare." -ForegroundColor Red
            Log "Port deja existent sau eroare la port pentru IP: $PrinterIP"
        }

        try {
            Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PrinterIP -Shared:$false -Published:$false -ErrorAction Stop
            Write-Host "  > Imprimanta " -NoNewline -ForegroundColor Yellow
            Write-Host $PrinterName -NoNewline -ForegroundColor DarkCyan
            Write-Host " a fost adaugata." -ForegroundColor Green
        }
        catch {
            Log "Eroare la instalarea imprimantei $PrinterName cu IP $($PrinterName): $_"
            Write-Error "Eroare la instalare. Vezi log.txt."
            continue
        }

        try {
            # Setare hartie A4
            Set-PrintConfiguration -PrinterName $PrinterName -PaperSize A4 -ErrorAction Stop
            Write-Host "  > Setare format hartie " -NoNewline -ForegroundColor Yellow
            Write-Host "A4" -ForegroundColor DarkCyan

            # Tiparire pe o singura fata
            Set-PrintConfiguration -PrinterName $PrinterName -DuplexingMode OneSided -ErrorAction Stop
            Write-Host "  > Tiparire pe o singura fata" -ForegroundColor Yellow

            $defaultChoice = Read-Host "`nSetezi aceasta imprimanta ca implicita? (ENTER = Nu, Y = Da)"
            if ($defaultChoice -match '^[Yy]') {
                #Set-Printer -Name $PrinterName -IsDefault $true
                $currentPrinter = Get-CimInstance -Class Win32_Printer -Filter "Name='$PrinterName'"
                Invoke-CimMethod -InputObject $currentPrinter -MethodName SetDefaultPrinter 
                Write-Host "  > Imprimanta " -NoNewline -ForegroundColor Yellow
                Write-Host $PrinterName -NoNewline -ForegroundColor DarkCyan
                Write-Host " a fost setata ca implicita." -ForegroundColor Yellow
                $WasDefault = "Da"
            }

        }
        catch {
            Log "Eroare la configurarea imprimantei $($PrinterName): $_"
            Write-Error "Eroare la configurare. Vezi log.txt."
        }
    }

    # === LOG FINAL PENTRU IMPRIMANTA CURENTa ===
    Log "Imprimanta instalata: $PrinterName"
    Log " - IP:        $PrinterIP"
    Log " - Driver:    $DriverName"
    Log " - Implicita: $WasDefault"
    Log " - Status:    SUCCES"
    Log (" - Durata:    {0:N2} secunde" -f $elapsedPrinter.TotalSeconds)

    Write-Host "`n * " -NoNewline -BackgroundColor Green -ForegroundColor Black
    Write-Host " Imprimanta " -NoNewline -ForegroundColor Green
    Write-Host $PrinterName -NoNewline -ForegroundColor DarkCyan
    Write-Host " instalata cu succes in " -NoNewline -ForegroundColor Green
    Write-Host ("{0:N2}" -f $elapsedPrinter.TotalSeconds) -NoNewline -ForegroundColor DarkCyan
    Write-Host " secunde" -ForegroundColor Green

    Write-CsvLog -printerIP $PrinterIP -printerName $PrinterName -driverName $DriverName -wasDefault $WasDefault

    $addAnother = Read-Host "`nDoresti sa adaugi o alta imprimanta? (Y/N)"
    Clear-Host
} while ($addAnother -match '^[Yy]')

Write-Host "`n Scriptul s-a incheiat. Toate imprimantele au fost instalate. "  -BackgroundColor Green -ForegroundColor Black
Log "=== Sfarsit rulare script ==="
Get-Printer * | Format-Table @{L='Nume';E='Name'},@{L=' Tip ';E='Type'},@{L='Driver';E='DriverName'},@{L='Stare ';E='PrinterStatus'} -autoSize
