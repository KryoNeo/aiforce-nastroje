# ZADÁNÍ — KONTRA

**KONTRA** · *Who is watching?* · *Velký bratr pod lupou*
Štítek: **FYI** · Úroveň: **BASIC** · Kánon: `AIF_TOOLS.md` · Verze zadání: 3 (odpovídá nástroji v5)

---

## Co má nástroj dělat

Napiš jeden skript **`kontra.ps1`** pro **PowerShell 5.1** na Windows 11. Skript zjistí, co Windows odesílá o uživateli a které programy právě komunikují s internetem. Výsledek **přeloží do laické řeči** a ukáže ho v jednom HTML reportu, který sám otevře v prohlížeči.

Skript **jen čte**: nic nemění, nic nevypíná a nepotřebuje práva správce. Nikam nic neodesílá, jedinou výjimkou je volitelný přepínač `-Mena` (zpětný DNS), který si uživatel zapne sám.

## Jazyk

Každý běh vyrobí **jeden report v jednom jazyce**, slovenském nebo českém (není to překlad hotového reportu). Jazyk určuje přepínač `-Jazyk sk|cs` (`cz` = `cs`). Bez přepínače se skript na začátku zeptá „1 = Slovensky, 2 = Cesky, Enter = 1“ a ptá se, dokud nedostane platnou odpověď.

Všechny texty jsou v jednom bloku na začátku skriptu, ve dvou jazykových blocích (sk, cs); slovníky nesou text obou jazyků u každé položky. Při startu skript ověří, že oba jazyky mají stejné texty, jinak skončí s chybou. Texty do konzole jsou bez diakritiky.

## Část A: nastavení soukromí

Pro každou položku zjisti stav a zobraz ho jako **semafor** (🟢 v pořádku · 🟠 odesílá údaje / zapnuto · ⚪ nezjištěno) s jednou větou, co to znamená, a jednou, kde to uživatel najde v Nastavení.

1. **Úroveň diagnostických údajů**: `AllowTelemetry` v `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection` a v `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection`. Chybějící hodnota = telemetrie běží. Na Home/Pro je *Required* nejnižší dosažitelná úroveň, tedy 🟢; řekni to pravdivě.
2. **Služba `DiagTrack`**: běží? spouští se automaticky?
3. **Plánované úlohy** v `\Microsoft\Windows\Application Experience\` a `\...\Customer Experience Improvement Program\`.
4. **Reklamní ID**: `Enabled` v `HKCU:\...\AdvertisingInfo`.
5. **Přizpůsobené prostředí**: `TailoredExperiencesWithDiagnosticDataEnabled` v `HKCU:\...\Privacy`.
6. **Historie aktivit**: `PublishUserActivities`, `UploadUserActivities` v `HKLM:\SOFTWARE\Policies\Microsoft\Windows\System`.
7. **Recall**: `DisableAIDataAnalysis` v `...\Policies\Microsoft\Windows\WindowsAI` (HKCU i HKLM). Pokud AI komponenta v systému není, napiš „není přítomný“. Pokud je a zásada ho nevypíná, ⚪ a pošli do Nastavení; uživatelský klíč Recallu nečti, není ověřený.

Pokud klíč chybí, nevymýšlej stav: „výchozí“ nebo ⚪ a vysvětli, co to znamená.

## Část B: kdo právě komunikuje s internetem

1. Sken výchozí **60 s** (`-Sekundy N`), každých 5 s vzorek `Get-NetTCPConnection -State Established`.
2. Vynech lokální adresy (`127.*`, `10.*`, `192.168.*`, `172.16–31.*`, `169.254.*`, `100.64–127.*`, `fe80:*`, `::1`).
3. Program podle `OwningProcess`; u `svchost` doplň služby (`Win32_Service`).
4. Jména domén z **lokální DNS paměti** (`Get-DnsClientCache`). S přepínačem **`-Mena`** navíc zpětný DNS (`Resolve-DnsName -Type PTR`), takto získaná jména označ.
5. Pro IP bez jména použij malý **slovník IP rozsahů** (Cloudflare, Google, AWS, Azure, Akamai…). Rozsahy ověř v registrech (RIPE, ARIN), nepiš je z paměti.
6. Seskup: **program → cíl → v kolika vzorcích · až kolik spojení najednou**. Cíl = řádek program + doména (nebo IP) + port.
7. Slovníky s laickým vysvětlením: **domény** (telemetrie · analytika · aktualizace · služba · aplikace · CDN · cloud), **programy**, **služby**, **porty** (80 zvýrazni jako nešifrovaný). Telemetrie a analytika jsou jen cíle, jejichž jediný účel je sběr údajů. Neznámé označ „neznámé – neznamená to automaticky nic špatného“.

## Report

- Jeden **samostatný HTML soubor** `KONTRA_report_RRRR-MM-DD_HHmm.html` vedle skriptu, bez externích zdrojů, skript ho otevře.
- **Hlavička:** datum, Windows, délka skenu, práva, zdroj jmen domén.
- **Verdikt** ve třech dlaždicích (velké číslo + popis začínající „Počet“, aby se nic neskloňovalo): (1) nastavení 🟠 ze 7 · (2) programů, v popisu i cílů celkem · (3) známých cílů telemetrie/analytiky, v popisu i cílů bez jména.
- **Tip:** „Pošli report své AI a proberte to spolu“ + ve stejném bloku upozornění, že report obsahuje jména programů a adres a že co uživatel nechce sdílet, má vymazat. Pod nadpisem části A poznámka, že cesty v Nastavení se mohou lišit podle verze Windows.
- **Pata:** *„KONTRA nic nezměnila, jen četla.“* + hranice: nevidí obsah; nevidí QUIC/UDP; minutový sken je snímek, pro skutečný obraz `-Sekundy 600`; `-Mena` vrátí často jen jméno poskytovatele.
- Tmavý přehledný vzhled v CSS proměnných (`:root`); design není cílem nástroje.

## Pravidla stavby

- PowerShell 5.1, žádné moduly. Soubor **UTF-8 s BOM**. Klíče v hashtable **nerozlišují velikost písmen**, žádné duplikáty typu `claude`/`Claude`.
- Bez práv správce; co se nedá přečíst, je ⚪, skript nespadne.
- Komentáře ve slovenštině, kód čitelný.

## Spuštění

```powershell
powershell -ExecutionPolicy Bypass -File .\kontra.ps1 -Mena
```

## Hotovo, když

- Skript proběhne bez chyby jako běžný uživatel, ve slovenštině i v češtině.
- Report obsahuje verdikt, tip, 7 položek části A a seznam programů části B.
- Žádná položka neukazuje vymyšlený stav.
- HTML funguje bez internetu, v systému se nic nezměnilo.
- `-Mena` pojmenuje většinu adres.
