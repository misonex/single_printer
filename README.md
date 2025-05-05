# SinglePrinter Package - Compatibil Windows 10/11
Instalează imprimante din rețea pe o stație de lucru locală cu sistem de operare Windows 10/11.

![Sigle Printer](https://github.com/misonex/single_printer/blob/main/single_printer.png?raw=true)

La rularea scriptului, acesta crează un fișier **log.txt** pentru fiecare sesiune de instalare și un fișier **installed_printers.csv** în care se vor găsi toate imprimantele instalate.
Dacă serverul nu este accesibil, vor fi create local.

## Conținut
- **Run.bat** - Lansează scriptul PowerShell cu permisiuni corecte (*Batch*)
- **single_printer.ps1** - Script instalare iimprimante (*PowerShell*)
- **README.txt** - Acest fișier
- **single_printer.png** - Screenshot execuție script
- Diverse directoare pentru drivere pentru imprimante.
  - HP_E40040_V3
  - HP_M402DNE
  - HP_M428
  - HP_M428_V4
  - Lexmark_MS510DN
  - Lexmark_MX410

## Pregătire
1. Setează calea pentru loguri către un server local în fișierul **single_printer.ps1**  (*linia 21*). Aceasta trebuie să fie accesibilă, cu drepturi de scriere.
2. Copiază driverele necesare în directoare specifice. Driverele sunt despachetate, nu sub forma fișierelor `setup.exe`.
3. Pentru a adăuga noi drivere se crează un director cu numele imprimantei în rădăcină. Se adaugă intrarea pentru meniu de genul:
  ```
    "N" = @{
      Title = "Imprimanta X"
      Name = "Imprimanta_X"
      Inf  = Join-Path -Path $PSScriptRoot -ChildPath "Imprimanta_X\abc00xyz.inf"
    }
  ```
  - **N** este numărul următor din meniu,
  - **Title** este numele imprimantei afișat în meniu,
  - **Name** este numele imprimantei pe care îl găsim în fișierul de instalare (*.inf),
  - **Inf** este fișierul de instalare al respectivei imprimante.

*Numele imprimantei îl găsim în fișierul `*.inf`. Se poate face o instalare de test manuală pentru a vedea cum este denumită imprimanta la instalarea pe stația Windows.*

## Executare
1. Rulează `Run.bat`.
2. Urmează instrucțiunile din consolă.
3. După finalizarea execuției scriptului vom găsi pe server (sau local) un fișier log de genul **log_192.168.0.22.txt** în care găsim informații despre imprimantele instalate pe stația de lucru cu respectivul IP. Deasemenea, în fișierul **installed_printers.csv** sunt adăugate noile instalări într-un tabel de forma:

| Data                | IP_Statie    | Nume_Statie | IP_Imprimanta | Nume_Imprimanta | Driver                                | Implicita |
| ------------------- | ------------ | ----------- | ------------- | --------------- | ------------------------------------- | --------- |
| 2025-05-05 10:10:10 | 192.168.0.12 | HP-27RP4D8  | 192.168.0.45  | HP Birou        | HP LaserJet Pro M402-M403 n-dne PCL-6 | Da        |

