# ZADANIE — KONTRA

**KONTRA** · *Who is watching?* · *Veľký brat pod lupou*
Štítok: **FYI** · Úroveň: **BASIC** · Kánon: `AIF_TOOLS.md` · Verzia zadania: 3 (zodpovedá nástroju v5)

---

## Čo má nástroj robiť

Napíš jeden skript **`kontra.ps1`** pre **PowerShell 5.1** na Windows 11. Skript zistí, čo Windows posiela o používateľovi a ktoré programy práve komunikujú s internetom. Výsledok **preloží do laickej reči** a ukáže ho v jednom HTML reporte, ktorý sám otvorí v prehliadači.

Skript **iba číta**: nič nemení, nič nevypína a nepotrebuje admin práva. Nikam nič neposiela, jedinou výnimkou je voliteľný prepínač `-Mena` (spätný DNS), ktorý si používateľ zapne sám.

## Jazyk

Každý beh vyrobí **jeden report v jednom jazyku**, slovenskom alebo českom (nie preklad hotového reportu). Jazyk určuje prepínač `-Jazyk sk|cs` (`cz` = `cs`). Bez prepínača sa skript na začiatku opýta „1 = Slovensky, 2 = Cesky, Enter = 1“ a pýta sa, kým nedostane platnú odpoveď.

Všetky texty sú v jednom bloku na začiatku skriptu, v dvoch jazykových blokoch (sk, cs); slovníky nesú text oboch jazykov pri každej položke. Pri štarte skript overí, že oba jazyky majú rovnaké texty, inak skončí s chybou. Texty do konzoly sú bez diakritiky.

## Časť A: nastavenia súkromia

Pre každú položku zisti stav a zobraz ho ako **semafor** (🟢 v poriadku · 🟠 posiela údaje / zapnuté · ⚪ nezistené) s jednou vetou, čo to znamená, a jednou, kde to používateľ nájde v Nastaveniach.

1. **Úroveň diagnostických údajov**: `AllowTelemetry` v `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection` a v `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection`. Chýbajúca hodnota = telemetria beží. Na Home/Pro je *Required* najnižšia dosiahnuteľná úroveň, teda 🟢; povedz to pravdivo.
2. **Služba `DiagTrack`**: beží? spúšťa sa automaticky?
3. **Plánované úlohy** v `\Microsoft\Windows\Application Experience\` a `\...\Customer Experience Improvement Program\`.
4. **Reklamné ID**: `Enabled` v `HKCU:\...\AdvertisingInfo`.
5. **Prispôsobené prostredie**: `TailoredExperiencesWithDiagnosticDataEnabled` v `HKCU:\...\Privacy`.
6. **História aktivít**: `PublishUserActivities`, `UploadUserActivities` v `HKLM:\SOFTWARE\Policies\Microsoft\Windows\System`.
7. **Recall**: `DisableAIDataAnalysis` v `...\Policies\Microsoft\Windows\WindowsAI` (HKCU aj HKLM). Ak AI komponent v systéme nie je, napíš „nie je prítomný“. Ak je a politika ho nevypína, ⚪ a pošli do Nastavení; používateľský kľúč Recallu nečítaj, nie je overený.

Ak kľúč chýba, nevymýšľaj stav: „predvolené“ alebo ⚪ a vysvetli, čo to znamená.

## Časť B: kto práve komunikuje s internetom

1. Sken predvolene **60 s** (`-Sekundy N`), každých 5 s vzorka `Get-NetTCPConnection -State Established`.
2. Vynechaj lokálne adresy (`127.*`, `10.*`, `192.168.*`, `172.16–31.*`, `169.254.*`, `100.64–127.*`, `fe80:*`, `::1`).
3. Program podľa `OwningProcess`; pri `svchost` doplň služby (`Win32_Service`).
4. Mená domén z **lokálnej DNS pamäte** (`Get-DnsClientCache`). S prepínačom **`-Mena`** navyše spätný DNS (`Resolve-DnsName -Type PTR`), takto získané mená označ.
5. Pre IP bez mena použi malý **slovník IP rozsahov** (Cloudflare, Google, AWS, Azure, Akamai…). Rozsahy over v registroch (RIPE, ARIN), nepíš ich z pamäti.
6. Zoskup: **program → cieľ → v koľkých vzorkách · až koľko spojení naraz**. Cieľ = riadok program + doména (alebo IP) + port.
7. Slovníky s laickým vysvetlením: **domény** (telemetria · analytika · aktualizácie · služba · aplikácia · CDN · cloud), **programy**, **služby**, **porty** (80 zvýrazni ako nešifrovaný). Telemetria a analytika sú iba ciele, ktorých jediný účel je zber údajov. Neznáme označ „neznáme – neznamená to automaticky nič zlé“.

## Report

- Jeden **samostatný HTML súbor** `KONTRA_report_RRRR-MM-DD_HHmm.html` vedľa skriptu, bez externých zdrojov, skript ho otvorí.
- **Hlavička:** dátum, Windows, dĺžka skenu, práva, zdroj mien domén.
- **Verdikt** v troch dlaždiciach (veľké číslo + popis začínajúci „Počet“, aby sa nič nesklonovalo): (1) nastavení 🟠 zo 7 · (2) programov, v popise aj cieľov spolu · (3) známych cieľov telemetrie/analytiky, v popise aj cieľov bez mena.
- **Tip:** „Pošli report svojej AI a preber to s ňou“ + v tom istom bloku upozornenie, že report obsahuje mená programov a adries a že čo používateľ nechce zdieľať, má vymazať. Pod nadpisom časti A poznámka, že cesty v Nastaveniach sa môžu líšiť podľa verzie Windows.
- **Päta:** *„KONTRA nič nezmenila, iba čítala.“* + hranice: nevidí obsah; nevidí QUIC/UDP; minútový sken je snímka, pre skutočný obraz `-Sekundy 600`; `-Mena` vráti často iba meno poskytovateľa.
- Tmavý prehľadný vzhľad v CSS premenných (`:root`); dizajn nie je cieľ nástroja.

## Pravidlá stavby

- PowerShell 5.1, žiadne moduly. Súbor **UTF-8 s BOM**. Kľúče v hashtable **nerozlišujú veľkosť písmen**, žiadne duplikáty typu `claude`/`Claude`.
- Bez admin práv; čo sa nedá prečítať, je ⚪, skript nespadne.
- Komentáre po slovensky, kód čitateľný.

## Spustenie

```powershell
powershell -ExecutionPolicy Bypass -File .\kontra.ps1 -Mena
```

## Hotovo, keď

- Skript prebehne bez chyby ako bežný používateľ, v slovenčine aj v češtine.
- Report obsahuje verdikt, tip, 7 položiek časti A a zoznam programov časti B.
- Žiadna položka neukazuje vymyslený stav.
- HTML funguje bez internetu, v systéme sa nič nezmenilo.
- `-Mena` pomenuje väčšinu adries.
