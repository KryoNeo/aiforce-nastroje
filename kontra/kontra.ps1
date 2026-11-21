<#
    KONTRA  ·  Who is watching?  ·  Veľký brat pod lupou
    ------------------------------------------------------
    FYI nástroj (AIForce). Iba číta. Nič nemení, nič nevypína,
    nikam nič neposiela, nič nesťahuje. Nepotrebuje admin práva.

    Spustenie:
        powershell -ExecutionPolicy Bypass -File .\kontra.ps1
        powershell -ExecutionPolicy Bypass -File .\kontra.ps1 -Jazyk cs
        powershell -ExecutionPolicy Bypass -File .\kontra.ps1 -Sekundy 300
        powershell -ExecutionPolicy Bypass -File .\kontra.ps1 -Mena

    -Jazyk = voliteľné. sk alebo cs (cz sa berie ako cs). Bez prepínača sa
             KONTRA na začiatku opýta, v akom jazyku má byť report.
    -Mena  = voliteľné. Pre IP adresy bez mena v lokálnej DNS pamäti
             urobí spätný DNS dopyt (jediný prípad, keď KONTRA sama
             niečo pošle na internet – a iba ak to zapneš).

    Cieľ: PowerShell 5.1 (súčasť Windows 11).
    Verzia: 5 (21. 11. 2026)
#>

param(
    # Dĺžka sledovania spojení v sekundách (predvolene 60).
    [int]$Sekundy = 60,
    # Spätný DNS dopyt pre IP adresy bez mena (voliteľné, predvolene vypnuté).
    [switch]$Mena,
    # Jazyk reportu: sk alebo cs (cz = cs). Bez prepínača sa KONTRA opýta na začiatku.
    [ValidateSet('sk', 'cs', 'cz')][string]$Jazyk
)

$ErrorActionPreference = 'Continue'
$Krok = 5   # každých 5 sekúnd jedna vzorka spojení

# ============================================================================
#  TEXTY  –  všetko, čo používateľ vidí, je v tomto bloku, v dvoch jazykoch
#  (sk, cs). Pri spustení KONTRA overí, že oba jazyky majú rovnaké kľúče.
#  Slovníky nesú pri každej položke text v oboch jazykoch (sk, cs).
# ============================================================================
$TL = @{
  sk = @{
    Nazov  = 'KONTRA'
    Slogan = 'Who is watching?'
    Spec   = 'Veľký brat pod lupou'

    # konzola (bez diakritiky, konzola 5.1 ju nemusí zobraziť správne)
    KonzolaSpec     = 'Velky brat pod lupou'
    KonzolaUvod     = 'KONTRA iba cita. Nic nemeni, nikam nic neposiela.'
    KonzolaCastA    = 'Cast A: citam nastavenia sukromia...'
    KonzolaCastB    = 'Cast B: sledujem, kto komunikuje s internetom ({0} s)...'
    KonzolaVzorka   = 'vzorka {0}/{1}, zatial {2} spojeni'
    KonzolaMena     = 'Prepinac -Mena: spatny DNS dopyt pre {0} IP adries bez mena...'
    KonzolaMenaOk   = '  najdene mena: {0} z {1}'
    KonzolaSuhrn    = 'Hotovo: programy: {0}, ciele na internete: {1}.'
    KonzolaReport   = 'Report: {0}'
    KonzolaOtvaram  = 'Otvaram report v prehliadaci.'
    KonzolaHotovo   = 'Hotovo. V systeme sa nic nezmenilo.'

    # slová, ktoré sa vkladajú do viet
    EdiciaNezname   = 'neznáma'
    SlovoPredvolene = 'predvolené'
    SlovoVypnute    = 'vypnuté'
    SlovoZapnute    = 'zapnuté'

    # stavy semaforu (Kon = skratka do konzoly bez diakritiky)
    Stav = @{
        OK        = @{ Ikona = [string][char]::ConvertFromUtf32(0x1F7E2); Text = 'v poriadku';     Css = 'ok';   Kon = 'OK' }
        POSIELA   = @{ Ikona = [string][char]::ConvertFromUtf32(0x1F7E0); Text = 'posiela údaje';  Css = 'warn'; Kon = 'POSIELA' }
        ZAPNUTE   = @{ Ikona = [string][char]::ConvertFromUtf32(0x1F7E0); Text = 'zapnuté';        Css = 'warn'; Kon = 'ZAPNUTE' }
        NEZISTENE = @{ Ikona = [string][char]::ConvertFromUtf32(0x26AA);  Text = 'nezistené';      Css = 'na';   Kon = 'NEZISTENE' }
    }

    # report – hlavička, verdikt, legenda, sekcie, päta
    ReportTitul       = 'KONTRA – report'
    ReportPodtitul    = 'Čo o tebe Windows posiela a kto práve komunikuje s internetom – preložené do ľudskej reči.'
    VerdiktA          = 'Počet nastavení súkromia, ktoré posielajú údaje alebo sú zapnuté (zo {0})'
    VerdiktB          = 'Počet programov, ktoré komunikovali s internetom (cieľov spolu: {0})'
    VerdiktTel        = 'Počet známych cieľov, ktoré sú telemetria alebo analytika (bez mena: {0} – môže byť čokoľvek)'
    TipNadpis         = 'Nie si si niečím istý, alebo ťa niečo vyľakalo?'
    TipText           = 'Pošli tento súbor (celý report) svojej AI – ChatGPT, Claude, Gemini alebo lokálnemu modelu – a preber to s ňou. Opýtaj sa: „Čo z toho je bežné a čo by som mal riešiť?“ KONTRA je iba lupa. Čo s tým urobíš, je na tebe.'
    TipPozor          = 'Pred odoslaním si report prečítaj: obsahuje mená tvojich programov a internetových adries. Čo nechceš zdieľať, zo súboru vymaž.'
    PoznamkaNavigacia = 'Poznámka: cesty v Nastaveniach sú podľa tvojej verzie Windows. Ak ich nájdeš pod trochu iným názvom alebo na inom mieste, nehľadaj chybu u seba, použi hľadanie v Nastaveniach a zadaj kľúčové slovo (napr. Diagnostika, História aktivít).'
    LegendaOK         = 'v poriadku – nič sa neposiela, alebo je to na najnižšej možnej úrovni'
    LegendaPosiela    = 'posiela údaje / zapnuté – stojí za to pozrieť sa na to v Nastaveniach'
    LegendaNezistene  = 'nezistené – KONTRA to bez admin práv alebo na tejto verzii Windows nevie prečítať'
    SekciaA           = 'Časť A · Nastavenia súkromia'
    SekciaB           = 'Časť B · Kto práve komunikuje s internetom'
    Zistene           = 'Zistené'
    CoToZnamena       = 'Čo to znamená'
    KdeToNajdem       = 'Kde to nájdem'
    MetaDatum         = 'Dátum'
    MetaWindows       = 'Windows'
    MetaSken          = 'Dĺžka skenu'
    MetaVzorky        = 'počet vzoriek'
    MetaPrava         = 'Práva'
    MetaMena          = 'Mená domén'
    MenaLokalne       = 'iba z lokálnej DNS pamäte (nič sa neposielalo)'
    MenaRev           = 'lokálna DNS pamäť + spätný DNS dopyt (prepínač -Mena)'
    PravaBezAdmin     = 'spustené ako bežný používateľ (bez admin práv)'
    PravaAdmin        = 'spustené s admin právami'
    SuhrnB            = 'Za {0} s KONTRA zachytila komunikáciu. Programy: {1} · ciele na internete: {2} · vzorka každých {3} s, počet vzoriek: {4}.'
    SuhrnBNic         = 'Za {0} s KONTRA nezachytila žiadne spojenie mimo lokálnej siete.'
    StlpecCiel        = 'Kam (doména alebo IP)'
    StlpecPort        = 'Port'
    StlpecVzorky      = 'Ako často'
    StlpecVyznam      = 'Čo to znamená'
    VzorkyText        = 'vzorky: {0} z {1}'
    NarazText         = 'až {0} naraz'
    Sluzby            = 'Služby v tomto procese'
    ProcesUkonceny    = '(proces sa medzitým ukončil)'
    IbaIP             = 'meno sa nenašlo v lokálnej DNS pamäti, zobrazená je IP adresa'
    IbaIPRev          = 'meno sa nenašlo ani spätným DNS dopytom, zobrazená je IP adresa'
    ZdrojRev          = 'spätný DNS'
    Nezname           = 'neznáme – neznamená to automaticky nič zlé'
    IPRozsah          = 'podľa rozsahu adries: '
    PataVeta          = 'KONTRA nič nezmenila, iba čítala.'
    PataHranice       = 'KONTRA vidí, KTO a KAM komunikuje, ale nie ČO posiela – prenos je šifrovaný. Mená domén berie z lokálnej DNS pamäte; prehliadače a niektoré aplikácie ju obchádzajú, preto pri nich často vidíš iba IP adresu. Na edíciách Windows Home a Pro sa telemetria nedá vypnúť úplne, minimum je úroveň Required.'
    PataRev           = 'Tento beh použil prepínač -Mena: pre IP adresy bez mena KONTRA urobila spätný DNS dopyt. Takto získané mená sú označené „spätný DNS“. Spätný DNS často vráti iba meno servera poskytovateľa (CDN, cloud), nie meno služby.'
    PataQuic          = 'Slepé miesto: KONTRA číta iba TCP spojenia. Prehliadače dnes posielajú veľkú časť prevádzky cez HTTP/3 (QUIC, protokol UDP) a tú Windows bez špeciálneho ovládača neukáže. Prehliadač teda komunikuje s viacerými miestami, než tu vidíš.'
    PataDlhsi         = 'Minútový sken je snímka, nie film. Telemetria Windows posiela údaje v dávkach raz za čas a stále otvorené spojenia (chat, hudba) vyzerajú ako najväčší hovorcovia iba preto, že sú otvorené. Pre skutočný obraz spusti: powershell -ExecutionPolicy Bypass -File .\kontra.ps1 -Sekundy 600 -Jazyk sk a nechaj počítač v pokoji.'
    PataPodpis        = 'KONTRA · nástroj AIForce · FYI · BASIC'

    TypBadge = @{
        telemetria   = 'TELEMETRIA'
        analytika    = 'ANALYTIKA'
        aktualizacie = 'AKTUALIZÁCIE'
        sluzba       = 'SLUŽBA'
        aplikacia    = 'APLIKÁCIA'
        cdn          = 'CDN'
        cloud        = 'CLOUD'
        nezname      = 'NEZNÁME'
    }

    # položky časti A
    Polozka = @{
        Telemetria = @{
            Nazov = 'Úroveň diagnostických údajov'
            Kon   = 'Uroven diagnostickych udajov'
            Kde   = 'Nastavenia › Súkromie a zabezpečenie › Diagnostika a pripomienky'
            Chyba = 'Hodnota AllowTelemetry nie je nastavená. Windows používa predvolenú úroveň, diagnostické údaje sa posielajú.'
            U0    = 'Nastavené na 0 (Security) – najnižšia možná úroveň.'
            U0Pro = 'Nastavené na 0 (Security), ale na edícii {0} to Windows berie ako 1 (Required). Nižšie sa tu ísť nedá.'
            U1    = 'Nastavené na 1 (Required) – posiela sa iba povinné minimum. Na edícii {0} je to najnižšia dosiahnuteľná úroveň.'
            U2    = 'Nastavené na 2 (Enhanced) – posiela sa viac než povinné minimum.'
            U3    = 'Nastavené na 3 (Optional) – posielajú sa všetky voliteľné diagnostické údaje vrátane informácií o používaní aplikácií a prehliadaní.'
            Co    = 'Diagnostické údaje sú správy o tom, ako tvoj počítač a aplikácie fungujú. Povinné minimum (Required) obsahuje hlavne informácie o zariadení a chybách; voliteľná úroveň pridáva aj to, ako Windows a aplikácie používaš.'
        }
        DiagTrack = @{
            Nazov   = 'Služba telemetrie (DiagTrack)'
            Kon     = 'Sluzba telemetrie (DiagTrack)'
            Kde     = 'Služby (services.msc) › Connected User Experiences and Telemetry'
            Bezi    = 'Služba beží a spúšťa sa {0}.'
            Stoji   = 'Služba momentálne nebeží, ale spúšťa sa {0}, takže sa znova zapne.'
            Vypnuta = 'Služba nebeží a je vypnutá (Disabled).'
            Chyba   = 'Služba DiagTrack sa v systéme nenašla.'
            Co      = 'DiagTrack je služba, ktorá diagnostické údaje zbiera a odosiela Microsoftu. Ak beží, telemetria je v prevádzke bez ohľadu na ostatné nastavenia.'
        }
        Ulohy = @{
            Nazov   = 'Plánované úlohy zberu údajov'
            Kon     = 'Planovane ulohy zberu udajov'
            Kde     = 'Plánovač úloh › Microsoft › Windows › Application Experience a Customer Experience Improvement Program'
            Zapnute = 'Zapnuté úlohy: {0}'
            Vypnute = 'Všetky nájdené úlohy sú vypnuté ({0}).'
            Ziadne  = 'V týchto priečinkoch sa nenašli žiadne úlohy, alebo ich nie je možné prečítať bez admin práv.'
            Co      = 'Tieto úlohy na pozadí pravidelne zbierajú informácie o kompatibilite programov a o používaní počítača a posielajú ich Microsoftu.'
        }
        Reklama = @{
            Nazov = 'Reklamné ID'
            Kon   = 'Reklamne ID'
            Kde   = 'Nastavenia › Súkromie a zabezpečenie › Všeobecné › Povoliť aplikáciám zobrazovať prispôsobené reklamy pomocou môjho reklamného ID'
            Zap   = 'Reklamné ID je zapnuté.'
            Vyp   = 'Reklamné ID je vypnuté.'
            Chyba = 'Hodnota nie je nastavená, Windows používa predvolený stav (zapnuté).'
            Co    = 'Reklamné ID je jedinečný identifikátor tvojho konta, podľa ktorého ti aplikácie z Microsoft Store zobrazujú cielené reklamy.'
        }
        Prisposobene = @{
            Nazov = 'Prispôsobené prostredie'
            Kon   = 'Prisposobene prostredie'
            Kde   = 'Nastavenia › Súkromie a zabezpečenie › Diagnostika a pripomienky › Prispôsobené prostredia'
            Zap   = 'Prispôsobené prostredie je zapnuté.'
            Vyp   = 'Prispôsobené prostredie je vypnuté.'
            Chyba = 'Hodnota nie je nastavená, Windows používa predvolený stav (zapnuté).'
            Co    = 'Windows používa tvoje diagnostické údaje na to, aby ti ponúkal tipy, reklamy a odporúčania ušité na mieru.'
        }
        Aktivity = @{
            Nazov = 'História aktivít'
            Kon   = 'Historia aktivit'
            Kde   = 'Nastavenia › Súkromie a zabezpečenie › História aktivít'
            Vyp   = 'Ukladanie aj odosielanie histórie aktivít je vypnuté politikou.'
            Zap   = 'Politika povoľuje históriu aktivít (ukladanie: {0}, odosielanie: {1}).'
            Chyba = 'Politika nie je nastavená, Windows používa predvolený stav – história aktivít sa ukladá.'
            Co    = 'História aktivít je záznam o tom, ktoré aplikácie, súbory a weby si otváral. Používa ju Windows na časovú os a odporúčania.'
        }
        Recall = @{
            Nazov       = 'Recall (snímky obrazovky pre AI)'
            Kon         = 'Recall (snimky obrazovky pre AI)'
            Kde         = 'Nastavenia › Súkromie a zabezpečenie › Recall a snímky'
            VypPolitika = 'Recall je vypnutý politikou (DisableAIDataAnalysis = 1).'
            Pritomny    = 'AI komponent Windows je v systéme prítomný, ale KONTRA nevie spoľahlivo zistiť, či je Recall zapnutý. Pozri do Nastavení; Recall existuje len na počítačoch Copilot+, ak ho tam nenájdeš, na tomto počítači nie je.'
            Nepritomny  = 'Recall nie je prítomný – AI komponent Windows sa v systéme nenašiel.'
            Co          = 'Recall pravidelne robí snímky obrazovky a ukladá ich, aby si neskôr vedel vyhľadávať, čo si videl. Snímky zostávajú v počítači, ale obsahujú všetko, čo bolo na obrazovke.'
        }
    }
  }

  cs = @{
    Nazov  = 'KONTRA'
    Slogan = 'Who is watching?'
    Spec   = 'Velký bratr pod lupou'

    # konzola (bez diakritiky, konzola 5.1 ji nemusí zobrazit správně)
    KonzolaSpec     = 'Velky bratr pod lupou'
    KonzolaUvod     = 'KONTRA jen cte. Nic nemeni, nikam nic neodesila.'
    KonzolaCastA    = 'Cast A: ctu nastaveni soukromi...'
    KonzolaCastB    = 'Cast B: sleduji, kdo komunikuje s internetem ({0} s)...'
    KonzolaVzorka   = 'vzorek {0}/{1}, zatim {2} spojeni'
    KonzolaMena     = 'Prepinac -Mena: zpetny DNS dotaz pro {0} IP adres bez jmena...'
    KonzolaMenaOk   = '  nalezena jmena: {0} z {1}'
    KonzolaSuhrn    = 'Hotovo: programy: {0}, cile na internetu: {1}.'
    KonzolaReport   = 'Report: {0}'
    KonzolaOtvaram  = 'Oteviram report v prohlizeci.'
    KonzolaHotovo   = 'Hotovo. V systemu se nic nezmenilo.'

    # slova, která se vkládají do vět
    EdiciaNezname   = 'neznámá'
    SlovoPredvolene = 'výchozí'
    SlovoVypnute    = 'vypnuto'
    SlovoZapnute    = 'zapnuto'

    # stavy semaforu (Kon = zkratka do konzole bez diakritiky)
    Stav = @{
        OK        = @{ Ikona = [string][char]::ConvertFromUtf32(0x1F7E2); Text = 'v pořádku';      Css = 'ok';   Kon = 'OK' }
        POSIELA   = @{ Ikona = [string][char]::ConvertFromUtf32(0x1F7E0); Text = 'odesílá údaje';  Css = 'warn'; Kon = 'ODESILA' }
        ZAPNUTE   = @{ Ikona = [string][char]::ConvertFromUtf32(0x1F7E0); Text = 'zapnuto';        Css = 'warn'; Kon = 'ZAPNUTO' }
        NEZISTENE = @{ Ikona = [string][char]::ConvertFromUtf32(0x26AA);  Text = 'nezjištěno';     Css = 'na';   Kon = 'NEZJISTENO' }
    }

    # report – hlavička, verdikt, legenda, sekce, pata
    ReportTitul       = 'KONTRA – report'
    ReportPodtitul    = 'Co o tobě Windows odesílá a kdo právě komunikuje s internetem – přeloženo do lidské řeči.'
    VerdiktA          = 'Počet nastavení soukromí, která odesílají údaje nebo jsou zapnutá (ze {0})'
    VerdiktB          = 'Počet programů, které komunikovaly s internetem (cílů celkem: {0})'
    VerdiktTel        = 'Počet známých cílů, které jsou telemetrie nebo analytika (bez jména: {0} – může být cokoli)'
    TipNadpis         = 'Něco ti není jasné, nebo tě něco znepokojilo?'
    TipText           = 'Pošli tento soubor (celý report) své AI – ChatGPT, Claude, Gemini nebo lokálnímu modelu – a proberte to spolu. Zeptej se: „Co z toho je běžné a co je potřeba řešit?“ KONTRA je jen lupa. Co s tím uděláš, je na tobě.'
    TipPozor          = 'Před odesláním si report přečti: obsahuje jména tvých programů a internetových adres. Co nechceš sdílet, ze souboru vymaž.'
    PoznamkaNavigacia = 'Poznámka: cesty v Nastavení se liší podle verze Windows. Pokud je najdeš pod trochu jiným názvem nebo na jiném místě, chyba není u tebe, použij vyhledávání v Nastavení a zadej klíčové slovo (např. Diagnostika, Historie aktivit).'
    LegendaOK         = 'v pořádku – nic se neodesílá, nebo je to na nejnižší možné úrovni'
    LegendaPosiela    = 'odesílá údaje / zapnuto – stojí za to podívat se na to v Nastavení'
    LegendaNezistene  = 'nezjištěno – KONTRA to bez práv správce nebo na této verzi Windows neumí přečíst'
    SekciaA           = 'Část A · Nastavení soukromí'
    SekciaB           = 'Část B · Kdo právě komunikuje s internetem'
    Zistene           = 'Zjištěno'
    CoToZnamena       = 'Co to znamená'
    KdeToNajdem       = 'Kde to najdu'
    MetaDatum         = 'Datum'
    MetaWindows       = 'Windows'
    MetaSken          = 'Délka skenu'
    MetaVzorky        = 'počet vzorků'
    MetaPrava         = 'Práva'
    MetaMena          = 'Jména domén'
    MenaLokalne       = 'pouze z lokální DNS paměti (nic se neodesílalo)'
    MenaRev           = 'lokální DNS paměť + zpětný DNS dotaz (přepínač -Mena)'
    PravaBezAdmin     = 'spuštěno jako běžný uživatel (bez práv správce)'
    PravaAdmin        = 'spuštěno s právy správce'
    SuhrnB            = 'Za {0} s KONTRA zachytila komunikaci. Programy: {1} · cíle na internetu: {2} · vzorek každých {3} s, počet vzorků: {4}.'
    SuhrnBNic         = 'Za {0} s KONTRA nezachytila žádné spojení mimo lokální síť.'
    StlpecCiel        = 'Kam (doména nebo IP)'
    StlpecPort        = 'Port'
    StlpecVzorky      = 'Jak často'
    StlpecVyznam      = 'Co to znamená'
    VzorkyText        = 'vzorky: {0} z {1}'
    NarazText         = 'až {0} najednou'
    Sluzby            = 'Služby v tomto procesu'
    ProcesUkonceny    = '(proces se mezitím ukončil)'
    IbaIP             = 'jméno se nenašlo v lokální DNS paměti, zobrazena je IP adresa'
    IbaIPRev          = 'jméno se nenašlo ani zpětným DNS dotazem, zobrazena je IP adresa'
    ZdrojRev          = 'zpětný DNS'
    Nezname           = 'neznámé – neznamená to automaticky nic špatného'
    IPRozsah          = 'podle rozsahu adres: '
    PataVeta          = 'KONTRA nic nezměnila, jen četla.'
    PataHranice       = 'KONTRA vidí, KDO a KAM komunikuje, ale ne CO odesílá – přenos je šifrovaný. Jména domén bere z lokální DNS paměti; prohlížeče a některé aplikace ji obcházejí, proto u nich často vidíš jen IP adresu. Na edicích Windows Home a Pro nelze telemetrii vypnout úplně, minimum je úroveň Required.'
    PataRev           = 'Tento běh použil přepínač -Mena: pro IP adresy bez jména provedla KONTRA zpětný DNS dotaz. Takto získaná jména jsou označena „zpětný DNS“. Zpětný DNS často vrátí jen jméno serveru poskytovatele (CDN, cloud), ne jméno služby.'
    PataQuic          = 'Slepé místo: KONTRA čte jen TCP spojení. Prohlížeče dnes posílají velkou část provozu přes HTTP/3 (QUIC, protokol UDP) a tu Windows bez speciálního ovladače neukáže. Prohlížeč tedy komunikuje s víc místy, než tady vidíš.'
    PataDlhsi         = 'Minutový sken je snímek, ne film. Telemetrie Windows odesílá údaje v dávkách jednou za čas a trvale otevřená spojení (chat, hudba) vypadají jako největší mluvčí jen proto, že jsou otevřená. Pro skutečný obraz spusť: powershell -ExecutionPolicy Bypass -File .\kontra.ps1 -Sekundy 600 -Jazyk cs a nech počítač v klidu.'
    PataPodpis        = 'KONTRA · nástroj AIForce · FYI · BASIC'

    TypBadge = @{
        telemetria   = 'TELEMETRIE'
        analytika    = 'ANALYTIKA'
        aktualizacie = 'AKTUALIZACE'
        sluzba       = 'SLUŽBA'
        aplikacia    = 'APLIKACE'
        cdn          = 'CDN'
        cloud        = 'CLOUD'
        nezname      = 'NEZNÁMÉ'
    }

    # položky části A
    Polozka = @{
        Telemetria = @{
            Nazov = 'Úroveň diagnostických údajů'
            Kon   = 'Uroven diagnostickych udaju'
            Kde   = 'Nastavení › Ochrana osobních údajů a zabezpečení › Diagnostika a zpětná vazba'
            Chyba = 'Hodnota AllowTelemetry není nastavena. Windows používá výchozí úroveň, diagnostické údaje se odesílají.'
            U0    = 'Nastaveno na 0 (Security) – nejnižší možná úroveň.'
            U0Pro = 'Nastaveno na 0 (Security), ale na edici {0} to Windows bere jako 1 (Required). Níž to nejde.'
            U1    = 'Nastaveno na 1 (Required) – odesílá se jen povinné minimum. Na edici {0} je to nejnižší dosažitelná úroveň.'
            U2    = 'Nastaveno na 2 (Enhanced) – odesílá se víc než povinné minimum.'
            U3    = 'Nastaveno na 3 (Optional) – odesílají se všechny volitelné diagnostické údaje včetně informací o používání aplikací a prohlížení.'
            Co    = 'Diagnostické údaje jsou zprávy o tom, jak tvůj počítač a aplikace fungují. Povinné minimum (Required) obsahuje hlavně informace o zařízení a chybách; volitelná úroveň přidává i to, jak Windows a aplikace používáš.'
        }
        DiagTrack = @{
            Nazov   = 'Služba telemetrie (DiagTrack)'
            Kon     = 'Sluzba telemetrie (DiagTrack)'
            Kde     = 'Služby (services.msc) › Connected User Experiences and Telemetry'
            Bezi    = 'Služba běží a spouští se {0}.'
            Stoji   = 'Služba momentálně neběží, ale spouští se {0}, takže se znovu zapne.'
            Vypnuta = 'Služba neběží a je vypnutá (Disabled).'
            Chyba   = 'Služba DiagTrack se v systému nenašla.'
            Co      = 'DiagTrack je služba, která diagnostické údaje sbírá a odesílá Microsoftu. Pokud běží, telemetrie je v provozu bez ohledu na ostatní nastavení.'
        }
        Ulohy = @{
            Nazov   = 'Plánované úlohy sběru údajů'
            Kon     = 'Planovane ulohy sberu udaju'
            Kde     = 'Plánovač úloh › Microsoft › Windows › Application Experience a Customer Experience Improvement Program'
            Zapnute = 'Zapnuté úlohy: {0}'
            Vypnute = 'Všechny nalezené úlohy jsou vypnuté ({0}).'
            Ziadne  = 'V těchto složkách se nenašly žádné úlohy, nebo je nelze přečíst bez práv správce.'
            Co      = 'Tyto úlohy na pozadí pravidelně sbírají informace o kompatibilitě programů a o používání počítače a odesílají je Microsoftu.'
        }
        Reklama = @{
            Nazov = 'Reklamní ID'
            Kon   = 'Reklamni ID'
            Kde   = 'Nastavení › Ochrana osobních údajů a zabezpečení › Obecné › personalizované reklamy pomocí mého reklamního ID'
            Zap   = 'Reklamní ID je zapnuté.'
            Vyp   = 'Reklamní ID je vypnuté.'
            Chyba = 'Hodnota není nastavena, Windows používá výchozí stav (zapnuto).'
            Co    = 'Reklamní ID je jedinečný identifikátor tvého účtu, podle kterého ti aplikace z Microsoft Store zobrazují cílené reklamy.'
        }
        Prisposobene = @{
            Nazov = 'Přizpůsobené prostředí'
            Kon   = 'Prizpusobene prostredi'
            Kde   = 'Nastavení › Ochrana osobních údajů a zabezpečení › Diagnostika a zpětná vazba › Přizpůsobená prostředí'
            Zap   = 'Přizpůsobené prostředí je zapnuté.'
            Vyp   = 'Přizpůsobené prostředí je vypnuté.'
            Chyba = 'Hodnota není nastavena, Windows používá výchozí stav (zapnuto).'
            Co    = 'Windows využívá tvé diagnostické údaje k tomu, aby ti nabízel tipy, reklamy a doporučení šitá na míru.'
        }
        Aktivity = @{
            Nazov = 'Historie aktivit'
            Kon   = 'Historie aktivit'
            Kde   = 'Nastavení › Ochrana osobních údajů a zabezpečení › Historie aktivit'
            Vyp   = 'Ukládání i odesílání historie aktivit je vypnuté zásadou.'
            Zap   = 'Zásada povoluje historii aktivit (ukládání: {0}, odesílání: {1}).'
            Chyba = 'Zásada není nastavena, Windows používá výchozí stav – historie aktivit se ukládá.'
            Co    = 'Historie aktivit je záznam o tom, které aplikace, soubory a weby byly na počítači otevřeny. Windows ji používá pro časovou osu a doporučení.'
        }
        Recall = @{
            Nazov       = 'Recall (snímky obrazovky pro AI)'
            Kon         = 'Recall (snimky obrazovky pro AI)'
            Kde         = 'Nastavení › Ochrana osobních údajů a zabezpečení › Recall a snímky'
            VypPolitika = 'Recall je vypnutý zásadou (DisableAIDataAnalysis = 1).'
            Pritomny    = 'AI komponenta Windows je v systému přítomná, ale KONTRA nedokáže spolehlivě zjistit, zda je Recall zapnutý. Podívej se do Nastavení; Recall existuje jen na počítačích Copilot+, pokud ho tam nenajdeš, na tomto počítači není.'
            Nepritomny  = 'Recall není přítomný – AI komponenta Windows se v systému nenašla.'
            Co          = 'Recall pravidelně pořizuje snímky obrazovky a ukládá je, aby šlo později vyhledat, co se na obrazovce zobrazilo. Snímky zůstávají v počítači, ale obsahují všechno, co bylo na obrazovce.'
        }
    }
  }
}

# Slovník domén: vzor → typ + vysvetlenie (sk, cs). Poradie je dôležité, platí prvá zhoda.
# Typy: telemetria (Windows/MS), analytika (zber údajov, ktorého jediný účel je analytika), aktualizacie, sluzba, aplikacia, cdn, cloud, nezname
$SlovnikDomen = @(
    # --- Microsoft: telemetria ---
    @{ Vzor = '*.events.data.microsoft.com';      Typ = 'telemetria';   sk = 'diagnostické a telemetrické údaje Microsoftu'; cs = 'diagnostická a telemetrická data Microsoftu' }
    @{ Vzor = '*.telemetry.microsoft.com';        Typ = 'telemetria';   sk = 'telemetria Microsoftu (hlásenia o chybách a používaní)'; cs = 'telemetrie Microsoftu (hlášení o chybách a používání)' }
    @{ Vzor = 'watson*.microsoft.com';            Typ = 'telemetria';   sk = 'hlásenia o chybách programov (Windows Error Reporting)'; cs = 'hlášení o chybách programů (Windows Error Reporting)' }
    @{ Vzor = 'settings-win.data.microsoft.com';  Typ = 'telemetria';   sk = 'nastavenia telemetrie a zber údajov Windows'; cs = 'nastavení telemetrie a sběr dat Windows' }
    @{ Vzor = 'vortex*.microsoft.com';            Typ = 'telemetria';   sk = 'zber diagnostických údajov Windows'; cs = 'sběr diagnostických dat Windows' }
    @{ Vzor = '*.data.microsoft.com';             Typ = 'telemetria';   sk = 'zber údajov Microsoftu'; cs = 'sběr dat Microsoftu' }
    # --- Microsoft: aktualizácie a služby ---
    @{ Vzor = '*.windowsupdate.com';              Typ = 'aktualizacie'; sk = 'Windows Update – sťahovanie aktualizácií a zoznamov certifikátov'; cs = 'Windows Update – stahování aktualizací a seznamů certifikátů' }
    @{ Vzor = '*.update.microsoft.com';           Typ = 'aktualizacie'; sk = 'Windows Update – kontrola aktualizácií'; cs = 'Windows Update – kontrola aktualizací' }
    @{ Vzor = '*.delivery.mp.microsoft.com';      Typ = 'aktualizacie'; sk = 'doručovanie aktualizácií a aplikácií (Delivery Optimization)'; cs = 'doručování aktualizací a aplikací (Delivery Optimization)' }
    @{ Vzor = '*.dsp.mp.microsoft.com';           Typ = 'aktualizacie'; sk = 'riadenie sťahovania aktualizácií'; cs = 'řízení stahování aktualizací' }
    @{ Vzor = '*.msftconnecttest.com';            Typ = 'sluzba';       sk = 'test, či je počítač pripojený na internet'; cs = 'test, zda je počítač připojený k internetu' }
    @{ Vzor = '*.msftncsi.com';                   Typ = 'sluzba';       sk = 'test, či je počítač pripojený na internet'; cs = 'test, zda je počítač připojený k internetu' }
    @{ Vzor = 'login.live.com';                   Typ = 'sluzba';       sk = 'prihlásenie do konta Microsoft'; cs = 'přihlášení k účtu Microsoft' }
    @{ Vzor = '*.login.microsoftonline.com';      Typ = 'sluzba';       sk = 'prihlásenie do konta Microsoft'; cs = 'přihlášení k účtu Microsoft' }
    @{ Vzor = '*.1drv.com';                       Typ = 'sluzba';       sk = 'OneDrive – synchronizácia súborov'; cs = 'OneDrive – synchronizace souborů' }
    @{ Vzor = '*.onedrive.com';                   Typ = 'sluzba';       sk = 'OneDrive – synchronizácia súborov'; cs = 'OneDrive – synchronizace souborů' }
    @{ Vzor = '*.storage.live.com';               Typ = 'sluzba';       sk = 'OneDrive – úložisko súborov'; cs = 'OneDrive – úložiště souborů' }
    @{ Vzor = '*.live.com';                       Typ = 'sluzba';       sk = 'služby konta Microsoft (Outlook, OneDrive, prihlásenie)'; cs = 'služby účtu Microsoft (Outlook, OneDrive, přihlášení)' }
    @{ Vzor = '*.bing.com';                       Typ = 'sluzba';       sk = 'Bing – vyhľadávanie v ponuke Štart, widgety, Edge'; cs = 'Bing – vyhledávání v nabídce Start, widgety, Edge' }
    @{ Vzor = '*.msn.com';                        Typ = 'sluzba';       sk = 'MSN – správy a widgety Windows'; cs = 'MSN – zprávy a widgety Windows' }
    @{ Vzor = '*.edge.microsoft.com';             Typ = 'sluzba';       sk = 'prehliadač Microsoft Edge'; cs = 'prohlížeč Microsoft Edge' }
    @{ Vzor = '*.msedge.net';                     Typ = 'sluzba';       sk = 'prehliadač Microsoft Edge'; cs = 'prohlížeč Microsoft Edge' }
    @{ Vzor = '*.wns.windows.com';                Typ = 'sluzba';       sk = 'push oznámenia Windows'; cs = 'push notifikace Windows' }
    @{ Vzor = '*.windows.com';                    Typ = 'sluzba';       sk = 'služby Windows (Store, licencie, oznámenia)'; cs = 'služby Windows (Store, licence, oznámení)' }
    @{ Vzor = '*.microsoft.com';                  Typ = 'sluzba';       sk = 'služby Microsoftu'; cs = 'služby Microsoftu' }
    @{ Vzor = '*.office.com';                     Typ = 'sluzba';       sk = 'Microsoft Office / Microsoft 365'; cs = 'Microsoft Office / Microsoft 365' }
    @{ Vzor = '*.office.net';                     Typ = 'sluzba';       sk = 'Microsoft Office / Microsoft 365'; cs = 'Microsoft Office / Microsoft 365' }
    @{ Vzor = '*.azureedge.net';                  Typ = 'cdn';          sk = 'CDN Microsoft Azure – doručovanie obsahu'; cs = 'CDN Microsoft Azure – doručování obsahu' }
    @{ Vzor = '*.trafficmanager.net';             Typ = 'cloud';        sk = 'smerovanie prevádzky Microsoft Azure'; cs = 'směrování provozu Microsoft Azure' }
    @{ Vzor = '*.windows.net';                    Typ = 'cloud';        sk = 'cloud Microsoft Azure (môže za ním byť ktorákoľvek služba)'; cs = 'cloud Microsoft Azure (může za ním být jakákoli služba)' }
    @{ Vzor = '*.azure.com';                      Typ = 'cloud';        sk = 'cloud Microsoft Azure'; cs = 'cloud Microsoft Azure' }
    # --- analytika aplikácií (zber údajov tretích strán) ---
    @{ Vzor = '*.datadoghq.com';                  Typ = 'analytika';    sk = 'Datadog – zber logov a diagnostiky aplikácie, ktorá ho používa'; cs = 'Datadog – sběr logů a diagnostiky aplikace, která ho používá' }
    @{ Vzor = '*.sentry.io';                      Typ = 'analytika';    sk = 'Sentry – hlásenia o chybách aplikácie'; cs = 'Sentry – hlášení o chybách aplikace' }
    @{ Vzor = '*.mediamelon.com';                 Typ = 'analytika';    sk = 'analytika prehrávania videa (ako a čo pozeráš)'; cs = 'analytika přehrávání videa (jak a co sleduješ)' }
    @{ Vzor = 'log.tailscale.com';                Typ = 'analytika';    sk = 'Tailscale – logy a diagnostika klienta'; cs = 'Tailscale – logy a diagnostika klienta' }
    @{ Vzor = '*.google-analytics.com';           Typ = 'analytika';    sk = 'Google Analytics – meranie návštevnosti'; cs = 'Google Analytics – měření návštěvnosti' }
    @{ Vzor = '*.app-measurement.com';            Typ = 'analytika';    sk = 'Google – meranie používania aplikácií'; cs = 'Google – měření používání aplikací' }
    @{ Vzor = '*.doubleclick.net';                Typ = 'analytika';    sk = 'Google – reklamná sieť'; cs = 'Google – reklamní síť' }
    @{ Vzor = '*.mixpanel.com';                   Typ = 'analytika';    sk = 'Mixpanel – analytika používania aplikácie'; cs = 'Mixpanel – analytika používání aplikace' }
    @{ Vzor = '*.segment.io';                     Typ = 'analytika';    sk = 'Segment – zber údajov o používaní'; cs = 'Segment – sběr dat o používání' }
    @{ Vzor = '*.amplitude.com';                  Typ = 'analytika';    sk = 'Amplitude – analytika používania aplikácie'; cs = 'Amplitude – analytika používání aplikace' }
    @{ Vzor = '*.hotjar.com';                     Typ = 'analytika';    sk = 'Hotjar – záznam správania na webe'; cs = 'Hotjar – záznam chování na webu' }
    @{ Vzor = '*.exp-tas.com';                    Typ = 'analytika';    sk = 'Microsoft – experimenty a zber údajov o používaní (VS Code, Edge, Office)'; cs = 'Microsoft – experimenty a sběr dat o používání (VS Code, Edge, Office)' }
    @{ Vzor = '*.facebook.com';                   Typ = 'aplikacia';    sk = 'Facebook / Meta (aj sledovacie pixely na weboch)'; cs = 'Facebook / Meta (i sledovací pixely na webech)' }
    @{ Vzor = '*.fbcdn.net';                      Typ = 'aplikacia';    sk = 'Facebook / Meta – obsah'; cs = 'Facebook / Meta – obsah' }
    # --- AI nástroje ---
    @{ Vzor = '*.openai.com';                     Typ = 'aplikacia';    sk = 'OpenAI – ChatGPT / Codex'; cs = 'OpenAI – ChatGPT / Codex' }
    @{ Vzor = '*.chatgpt.com';                    Typ = 'aplikacia';    sk = 'ChatGPT'; cs = 'ChatGPT' }
    @{ Vzor = '*.oaistatic.com';                  Typ = 'aplikacia';    sk = 'ChatGPT – statický obsah'; cs = 'ChatGPT – statický obsah' }
    @{ Vzor = '*.anthropic.com';                  Typ = 'aplikacia';    sk = 'Anthropic – Claude'; cs = 'Anthropic – Claude' }
    @{ Vzor = '*.claude.ai';                      Typ = 'aplikacia';    sk = 'Claude'; cs = 'Claude' }
    @{ Vzor = '*.intercom.io';                    Typ = 'sluzba';       sk = 'Intercom – podporný chat vstavaný v aplikácii'; cs = 'Intercom – podpůrný chat zabudovaný v aplikaci' }
    @{ Vzor = '*.ollama.com';                     Typ = 'aplikacia';    sk = 'Ollama – kontrola aktualizácií a sťahovanie modelov'; cs = 'Ollama – kontrola aktualizací a stahování modelů' }
    @{ Vzor = 'ai-backend-service.docker.com';    Typ = 'aplikacia';    sk = 'Docker – cloudový AI asistent (Gordon); drží spojenie aj bez použitia'; cs = 'Docker – cloudový AI asistent (Gordon); drží spojení i bez použití' }
    @{ Vzor = '*.docker.com';                     Typ = 'aplikacia';    sk = 'Docker'; cs = 'Docker' }
    @{ Vzor = '*.docker.io';                      Typ = 'aplikacia';    sk = 'Docker Hub – sťahovanie obrazov'; cs = 'Docker Hub – stahování obrazů' }
    # --- bežné aplikácie a služby ---
    @{ Vzor = 'mtalk.google.com';                 Typ = 'sluzba';       sk = 'Google push oznámenia (FCM) – používa ich veľa aplikácií'; cs = 'Google push notifikace (FCM) – používá je spousta aplikací' }
    @{ Vzor = '*.googleapis.com';                 Typ = 'aplikacia';    sk = 'Google – služby a API'; cs = 'Google – služby a API' }
    @{ Vzor = '*.gstatic.com';                    Typ = 'aplikacia';    sk = 'Google – statický obsah'; cs = 'Google – statický obsah' }
    @{ Vzor = '*.bc.googleusercontent.com';       Typ = 'cloud';        sk = 'cloud Google (môže za ním byť ktorákoľvek služba, napr. Spotify)'; cs = 'cloud Google (může za ním být jakákoli služba, např. Spotify)' }
    @{ Vzor = '*.googleusercontent.com';          Typ = 'aplikacia';    sk = 'Google – používateľský obsah (Drive, Fotky)'; cs = 'Google – uživatelský obsah (Disk, Fotky)' }
    @{ Vzor = '*.google.com';                     Typ = 'aplikacia';    sk = 'Google'; cs = 'Google' }
    @{ Vzor = '*.1e100.net';                      Typ = 'cloud';        sk = 'servery Google (môže za nimi byť ktorákoľvek služba Google)'; cs = 'servery Google (může za nimi být jakákoli služba Google)' }
    @{ Vzor = '*.youtube.com';                    Typ = 'aplikacia';    sk = 'YouTube'; cs = 'YouTube' }
    @{ Vzor = '*.ytimg.com';                      Typ = 'aplikacia';    sk = 'YouTube – obrázky'; cs = 'YouTube – obrázky' }
    @{ Vzor = '*.nvidia.com';                     Typ = 'aplikacia';    sk = 'NVIDIA – ovládače, NVIDIA App, telemetria NVIDIA'; cs = 'NVIDIA – ovladače, NVIDIA App, telemetrie NVIDIA' }
    @{ Vzor = '*.steampowered.com';               Typ = 'aplikacia';    sk = 'Steam'; cs = 'Steam' }
    @{ Vzor = '*.steamcontent.com';               Typ = 'aplikacia';    sk = 'Steam – sťahovanie hier'; cs = 'Steam – stahování her' }
    @{ Vzor = '*.epicgames.com';                  Typ = 'aplikacia';    sk = 'Epic Games'; cs = 'Epic Games' }
    @{ Vzor = '*.discord.com';                    Typ = 'aplikacia';    sk = 'Discord'; cs = 'Discord' }
    @{ Vzor = '*.discordapp.com';                 Typ = 'aplikacia';    sk = 'Discord'; cs = 'Discord' }
    @{ Vzor = '*.spotify.com';                    Typ = 'aplikacia';    sk = 'Spotify'; cs = 'Spotify' }
    @{ Vzor = '*.scdn.co';                        Typ = 'aplikacia';    sk = 'Spotify – obsah'; cs = 'Spotify – obsah' }
    @{ Vzor = '*.hbomax.com';                     Typ = 'aplikacia';    sk = 'HBO Max'; cs = 'HBO Max' }
    @{ Vzor = '*.max.com';                        Typ = 'aplikacia';    sk = 'Max (HBO)'; cs = 'Max (HBO)' }
    @{ Vzor = '*.discomax.com';                   Typ = 'aplikacia';    sk = 'HBO Max (Warner Bros. Discovery)'; cs = 'HBO Max (Warner Bros. Discovery)' }
    @{ Vzor = '*.netflix.com';                    Typ = 'aplikacia';    sk = 'Netflix'; cs = 'Netflix' }
    @{ Vzor = '*.nflxvideo.net';                  Typ = 'aplikacia';    sk = 'Netflix – video'; cs = 'Netflix – video' }
    @{ Vzor = '*.twitch.tv';                      Typ = 'aplikacia';    sk = 'Twitch'; cs = 'Twitch' }
    @{ Vzor = '*.kick.com';                       Typ = 'aplikacia';    sk = 'Kick'; cs = 'Kick' }
    @{ Vzor = '*.tailscale.com';                  Typ = 'aplikacia';    sk = 'Tailscale – súkromná VPN sieť medzi tvojimi zariadeniami'; cs = 'Tailscale – soukromá VPN síť mezi tvými zařízeními' }
    @{ Vzor = '*.tailscale.io';                   Typ = 'aplikacia';    sk = 'Tailscale – koordinačný server'; cs = 'Tailscale – koordinační server' }
    @{ Vzor = '*.seznam.cz';                      Typ = 'aplikacia';    sk = 'Seznam.cz (pošta, vyhľadávanie)'; cs = 'Seznam.cz (e-mail, vyhledávání)' }
    @{ Vzor = '*.szn.cz';                         Typ = 'aplikacia';    sk = 'Seznam.cz – oznámenia a obsah'; cs = 'Seznam.cz – notifikace a obsah' }
    @{ Vzor = '*.myshoptet.com';                  Typ = 'aplikacia';    sk = 'Shoptet – e-shopová platforma (administrácia, webmail)'; cs = 'Shoptet – e-shopová platforma (administrace, webmail)' }
    @{ Vzor = '*.anycast.net';                    Typ = 'cloud';        sk = 'anycast server poskytovateľa (často relé VPN alebo CDN)'; cs = 'anycast server poskytovatele (často relé VPN nebo CDN)' }
    @{ Vzor = '*.mapy.cz';                        Typ = 'aplikacia';    sk = 'Mapy.cz'; cs = 'Mapy.cz' }
    @{ Vzor = '*.apple.com';                      Typ = 'aplikacia';    sk = 'Apple (iCloud, iTunes)'; cs = 'Apple (iCloud, iTunes)' }
    @{ Vzor = '*.icloud.com';                     Typ = 'aplikacia';    sk = 'Apple iCloud'; cs = 'Apple iCloud' }
    @{ Vzor = '*.dropbox.com';                    Typ = 'aplikacia';    sk = 'Dropbox'; cs = 'Dropbox' }
    @{ Vzor = '*.github.com';                     Typ = 'aplikacia';    sk = 'GitHub'; cs = 'GitHub' }
    @{ Vzor = '*.githubusercontent.com';          Typ = 'aplikacia';    sk = 'GitHub – obsah'; cs = 'GitHub – obsah' }
    @{ Vzor = '*.slack.com';                      Typ = 'aplikacia';    sk = 'Slack'; cs = 'Slack' }
    @{ Vzor = '*.zoom.us';                        Typ = 'aplikacia';    sk = 'Zoom'; cs = 'Zoom' }
    @{ Vzor = '*.whatsapp.net';                   Typ = 'aplikacia';    sk = 'WhatsApp'; cs = 'WhatsApp' }
    @{ Vzor = '*.telegram.org';                   Typ = 'aplikacia';    sk = 'Telegram'; cs = 'Telegram' }
    @{ Vzor = '*.adobe.com';                      Typ = 'aplikacia';    sk = 'Adobe (Creative Cloud, Acrobat)'; cs = 'Adobe (Creative Cloud, Acrobat)' }
    @{ Vzor = '*.mozilla.com';                    Typ = 'aplikacia';    sk = 'Mozilla – Firefox (aktualizácie, synchronizácia)'; cs = 'Mozilla – Firefox (aktualizace, synchronizace)' }
    @{ Vzor = '*.mozilla.net';                    Typ = 'aplikacia';    sk = 'Mozilla – Firefox'; cs = 'Mozilla – Firefox' }
    @{ Vzor = '*.brave.com';                      Typ = 'aplikacia';    sk = 'Brave – prehliadač'; cs = 'Brave – prohlížeč' }
    # --- CDN a cloud (za nimi môže byť čokoľvek) ---
    @{ Vzor = '*.akamaiedge.net';                 Typ = 'cdn';          sk = 'CDN Akamai – doručovanie obsahu (prechádzajú cez ne aktualizácie aj weby)'; cs = 'CDN Akamai – doručování obsahu (procházejí přes ně aktualizace i weby)' }
    @{ Vzor = '*.akamai.net';                     Typ = 'cdn';          sk = 'CDN Akamai – doručovanie obsahu'; cs = 'CDN Akamai – doručování obsahu' }
    @{ Vzor = '*.akamaitechnologies.com';         Typ = 'cdn';          sk = 'CDN Akamai – doručovanie obsahu'; cs = 'CDN Akamai – doručování obsahu' }
    @{ Vzor = '*.cloudfront.net';                 Typ = 'cdn';          sk = 'CDN Amazon CloudFront – doručovanie obsahu'; cs = 'CDN Amazon CloudFront – doručování obsahu' }
    @{ Vzor = '*.cloudflare.com';                 Typ = 'cdn';          sk = 'Cloudflare – doručovanie obsahu a DNS'; cs = 'Cloudflare – doručování obsahu a DNS' }
    @{ Vzor = '*.fastly.net';                     Typ = 'cdn';          sk = 'CDN Fastly – doručovanie obsahu'; cs = 'CDN Fastly – doručování obsahu' }
    @{ Vzor = '*.amazonaws.com';                  Typ = 'cloud';        sk = 'cloud Amazon AWS (môže za ním byť ktorákoľvek služba)'; cs = 'cloud Amazon AWS (může za ním být jakákoli služba)' }
    @{ Vzor = '*.linodeusercontent.com';          Typ = 'cloud';        sk = 'cloud Linode / Akamai'; cs = 'cloud Linode / Akamai' }
    @{ Vzor = '*.digitalocean.com';               Typ = 'cloud';        sk = 'cloud DigitalOcean'; cs = 'cloud DigitalOcean' }
    @{ Vzor = '*.hetzner.com';                    Typ = 'cloud';        sk = 'cloud Hetzner'; cs = 'cloud Hetzner' }
)

# Slovník IP rozsahov: regex → typ + vysvetlenie. Použije sa, keď adresa nemá meno. Platí prvá zhoda.
# Rozsahy Akamai, Seznam a Tailscale sú overené podľa registrov (RIPE, ARIN, 21. 11. 2026).
$SlovnikIP = @(
    @{ Vzor = '^104\.(1[6-9]|2[0-3])\.';           Typ = 'cdn';       sk = 'Cloudflare – za ním býva web alebo aplikácia (napr. ChatGPT, Discord)'; cs = 'Cloudflare – za ním bývá web nebo aplikace (např. ChatGPT, Discord)' }
    @{ Vzor = '^172\.(6[4-9]|7[01])\.';            Typ = 'cdn';       sk = 'Cloudflare – za ním býva web alebo aplikácia (napr. ChatGPT, Discord)'; cs = 'Cloudflare – za ním bývá web nebo aplikace (např. ChatGPT, Discord)' }
    @{ Vzor = '^160\.79\.10[45]\.';                Typ = 'aplikacia'; sk = 'Anthropic – Claude'; cs = 'Anthropic – Claude' }
    @{ Vzor = '^199\.232\.';                       Typ = 'cdn';       sk = 'CDN Fastly – doručovanie obsahu (napr. Mozilla, GitHub)'; cs = 'CDN Fastly – doručování obsahu (např. Mozilla, GitHub)' }
    @{ Vzor = '^199\.165\.136\.';                  Typ = 'aplikacia'; sk = 'Tailscale – servery služby'; cs = 'Tailscale – servery služby' }
    @{ Vzor = '^13\.107\.';                        Typ = 'sluzba';    sk = 'Microsoft – služby (Office, Edge, Bing)'; cs = 'Microsoft – služby (Office, Edge, Bing)' }
    @{ Vzor = '^150\.171\.';                       Typ = 'sluzba';    sk = 'Microsoft – služby (Edge, Bing, Store)'; cs = 'Microsoft – služby (Edge, Bing, Store)' }
    @{ Vzor = '^172\.(1[6-8][0-9]|19[01])\.';      Typ = 'cloud';     sk = 'cloud Microsoft Azure (môže za ním byť ktorákoľvek služba)'; cs = 'cloud Microsoft Azure (může za ním být jakákoli služba)' }
    @{ Vzor = '^20\.';                             Typ = 'cloud';     sk = 'cloud Microsoft Azure (môže za ním byť ktorákoľvek služba)'; cs = 'cloud Microsoft Azure (může za ním být jakákoli služba)' }
    @{ Vzor = '^40\.(7[4-9]|8[0-9]|9[0-9]|1[01][0-9]|12[0-7])\.'; Typ = 'cloud'; sk = 'cloud Microsoft Azure'; cs = 'cloud Microsoft Azure' }
    @{ Vzor = '^52\.';                             Typ = 'cloud';     sk = 'cloud Amazon AWS alebo Microsoft Azure'; cs = 'cloud Amazon AWS nebo Microsoft Azure' }
    @{ Vzor = '^3\.';                              Typ = 'cloud';     sk = 'cloud Amazon AWS (môže za ním byť ktorákoľvek služba)'; cs = 'cloud Amazon AWS (může za ním být jakákoli služba)' }
    @{ Vzor = '^(34|35)\.';                        Typ = 'cloud';     sk = 'cloud Google alebo Amazon AWS (môže za ním byť ktorákoľvek služba)'; cs = 'cloud Google nebo Amazon AWS (může za ním být jakákoli služba)' }
    @{ Vzor = '^(64\.233|66\.249|74\.125|142\.25[0-1]|172\.217|172\.253|216\.58)\.'; Typ = 'cloud'; sk = 'servery Google'; cs = 'servery Google' }
    @{ Vzor = '^77\.75\.7[2-9]\.';                 Typ = 'aplikacia'; sk = 'Seznam.cz'; cs = 'Seznam.cz' }
    @{ Vzor = '^(2\.(1[6-9]|2[0-3])|23\.([0-9]|1[0-5]|3[2-9]|[45][0-9]|6[0-7]|7[2-9]|19[2-9]|2[01][0-9]|22[0-3])|88\.221|92\.12[23]|95\.10[01]|104\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])|184\.8[4-7])\.'; Typ = 'cdn'; sk = 'Akamai – doručovanie obsahu (CDN); prechádzajú cez ňu weby aj aktualizácie'; cs = 'Akamai – doručování obsahu (CDN); procházejí přes ni weby i aktualizace' }
)

# Slovník programov: meno procesu → vysvetlenie (sk, cs)
$SlovnikProgramov = @{
    'svchost'            = @{ sk = 'hostiteľ služieb Windows – o tom, čo robí, rozhodujú služby, ktoré v ňom bežia'; cs = 'hostitel služeb Windows – o tom, co dělá, rozhodují služby, které v něm běží' }
    'System'             = @{ sk = 'jadro Windows (sieťové zdieľanie, SMB, ovládače)'; cs = 'jádro Windows (sdílení v síti, SMB, ovladače)' }
    'MsMpEng'            = @{ sk = 'Microsoft Defender – antivírus'; cs = 'Microsoft Defender – antivirus' }
    'SearchHost'         = @{ sk = 'vyhľadávanie Windows (ponuka Štart)'; cs = 'vyhledávání Windows (nabídka Start)' }
    'StartMenuExperienceHost' = @{ sk = 'ponuka Štart'; cs = 'nabídka Start' }
    'explorer'           = @{ sk = 'Prieskumník Windows a pracovná plocha'; cs = 'Průzkumník Windows a plocha' }
    'msedge'             = @{ sk = 'prehliadač Microsoft Edge'; cs = 'prohlížeč Microsoft Edge' }
    'msedgewebview2'     = @{ sk = 'Edge WebView – vstavaný prehliadač v aplikáciách Windows a tretích strán'; cs = 'Edge WebView – vestavěný prohlížeč v aplikacích Windows a třetích stran' }
    'OneDrive'           = @{ sk = 'OneDrive – synchronizácia súborov do cloudu Microsoftu'; cs = 'OneDrive – synchronizace souborů do cloudu Microsoftu' }
    'WidgetService'      = @{ sk = 'widgety Windows (počasie, správy)'; cs = 'widgety Windows (počasí, zprávy)' }
    'Widgets'            = @{ sk = 'widgety Windows (počasie, správy)'; cs = 'widgety Windows (počasí, zprávy)' }
    'SystemSettings'     = @{ sk = 'aplikácia Nastavenia'; cs = 'aplikace Nastavení' }
    'backgroundTaskHost' = @{ sk = 'úlohy aplikácií z Microsoft Store na pozadí'; cs = 'úlohy aplikací z Microsoft Store na pozadí' }
    'RuntimeBroker'      = @{ sk = 'sprostredkovateľ oprávnení aplikácií Store'; cs = 'prostředník oprávnění aplikací Store' }
    'WinStore.App'       = @{ sk = 'Microsoft Store'; cs = 'Microsoft Store' }
    'NVDisplay.Container'= @{ sk = 'NVIDIA – ovládač grafickej karty a jeho služby'; cs = 'NVIDIA – ovladač grafické karty a jeho služby' }
    'nvcontainer'        = @{ sk = 'NVIDIA – NVIDIA App / GeForce Experience'; cs = 'NVIDIA – NVIDIA App / GeForce Experience' }
    'NVIDIA Overlay'     = @{ sk = 'NVIDIA – herný overlay'; cs = 'NVIDIA – herní overlay' }
    'steam'              = @{ sk = 'Steam'; cs = 'Steam' }
    'steamwebhelper'     = @{ sk = 'Steam – vstavaný prehliadač'; cs = 'Steam – vestavěný prohlížeč' }
    'EpicGamesLauncher'  = @{ sk = 'Epic Games Launcher'; cs = 'Epic Games Launcher' }
    'EpicWebHelper'      = @{ sk = 'Epic Games – vstavaný prehliadač'; cs = 'Epic Games – vestavěný prohlížeč' }
    'Discord'            = @{ sk = 'Discord'; cs = 'Discord' }
    'Spotify'            = @{ sk = 'Spotify'; cs = 'Spotify' }
    'chrome'             = @{ sk = 'prehliadač Google Chrome'; cs = 'prohlížeč Google Chrome' }
    'firefox'            = @{ sk = 'prehliadač Mozilla Firefox'; cs = 'prohlížeč Mozilla Firefox' }
    'brave'              = @{ sk = 'prehliadač Brave'; cs = 'prohlížeč Brave' }
    'opera'              = @{ sk = 'prehliadač Opera'; cs = 'prohlížeč Opera' }
    'vivaldi'            = @{ sk = 'prehliadač Vivaldi'; cs = 'prohlížeč Vivaldi' }
    'Teams'              = @{ sk = 'Microsoft Teams'; cs = 'Microsoft Teams' }
    'ms-teams'           = @{ sk = 'Microsoft Teams'; cs = 'Microsoft Teams' }
    'OUTLOOK'            = @{ sk = 'Microsoft Outlook'; cs = 'Microsoft Outlook' }
    'olk'                = @{ sk = 'Microsoft Outlook (nový)'; cs = 'Microsoft Outlook (nový)' }
    'Code'               = @{ sk = 'Visual Studio Code'; cs = 'Visual Studio Code' }
    'Cursor'             = @{ sk = 'Cursor – editor kódu s AI'; cs = 'Cursor – editor kódu s AI' }
    'python'             = @{ sk = 'Python'; cs = 'Python' }
    'node'               = @{ sk = 'Node.js'; cs = 'Node.js' }
    'ollama'             = @{ sk = 'Ollama – lokálny AI model'; cs = 'Ollama – lokální AI model' }
    'ollama app'         = @{ sk = 'Ollama – aplikácia v lište (kontroluje aktualizácie)'; cs = 'Ollama – aplikace v liště (kontroluje aktualizace)' }
    'docker-agent'       = @{ sk = 'Docker Desktop – AI asistent (Gordon), cloudová časť'; cs = 'Docker Desktop – AI asistent (Gordon), cloudová část' }
    'Docker Desktop'     = @{ sk = 'Docker Desktop'; cs = 'Docker Desktop' }
    'com.docker.backend' = @{ sk = 'Docker Desktop – jadro'; cs = 'Docker Desktop – jádro' }
    'LM Studio'          = @{ sk = 'LM Studio – lokálny AI model'; cs = 'LM Studio – lokální AI model' }
    'ChatGPT'            = @{ sk = 'ChatGPT – aplikácia OpenAI'; cs = 'ChatGPT – aplikace OpenAI' }
    'codex'              = @{ sk = 'Codex – AI agent OpenAI (príkazový riadok)'; cs = 'Codex – AI agent OpenAI (příkazový řádek)' }
    'claude'             = @{ sk = 'Claude – aplikácia Anthropic (alebo Claude Code)'; cs = 'Claude – aplikace Anthropic (nebo Claude Code)' }
    'tailscaled'         = @{ sk = 'Tailscale – súkromná VPN sieť medzi tvojimi zariadeniami (služba)'; cs = 'Tailscale – soukromá VPN síť mezi tvými zařízeními (služba)' }
    'tailscale-ipn'      = @{ sk = 'Tailscale – ikona a ovládanie v lište'; cs = 'Tailscale – ikona a ovládání v liště' }
    'Zoom'               = @{ sk = 'Zoom'; cs = 'Zoom' }
    'WhatsApp'           = @{ sk = 'WhatsApp'; cs = 'WhatsApp' }
    'Telegram'           = @{ sk = 'Telegram'; cs = 'Telegram' }
    'Signal'             = @{ sk = 'Signal'; cs = 'Signal' }
    'slack'              = @{ sk = 'Slack'; cs = 'Slack' }
    'Notion'             = @{ sk = 'Notion'; cs = 'Notion' }
    'Dropbox'            = @{ sk = 'Dropbox'; cs = 'Dropbox' }
    'GoogleDriveFS'      = @{ sk = 'Google Drive'; cs = 'Google Disk' }
    'obs64'              = @{ sk = 'OBS Studio – nahrávanie a streamovanie'; cs = 'OBS Studio – nahrávání a streamování' }
    'vlc'                = @{ sk = 'VLC prehrávač'; cs = 'přehrávač VLC' }
    'lsass'              = @{ sk = 'overovanie prihlásenia Windows'; cs = 'ověřování přihlášení Windows' }
    'wininit'            = @{ sk = 'spúšťanie systémových služieb Windows'; cs = 'spouštění systémových služeb Windows' }
    'MoUsoCoreWorker'    = @{ sk = 'Windows Update – pracovný proces'; cs = 'Windows Update – pracovní proces' }
    'SecurityHealthService' = @{ sk = 'Zabezpečenie Windows (Defender) – stav ochrany'; cs = 'Zabezpečení Windows (Defender) – stav ochrany' }
}

# Slovník služieb: meno služby → vysvetlenie (prípona _xxxx pri službách na používateľa sa odstraňuje)
$SlovnikSluzieb = @{
    'DiagTrack'          = @{ sk = 'telemetria Windows (Connected User Experiences and Telemetry)'; cs = 'telemetrie Windows (Connected User Experiences and Telemetry)' }
    'dmwappushservice'   = @{ sk = 'smerovanie správ pre telemetriu a správu zariadení'; cs = 'směrování zpráv pro telemetrii a správu zařízení' }
    'wuauserv'           = @{ sk = 'Windows Update'; cs = 'Windows Update' }
    'UsoSvc'             = @{ sk = 'Windows Update – orchestrácia'; cs = 'Windows Update – orchestrace' }
    'WaaSMedicSvc'       = @{ sk = 'Windows Update – oprava služby aktualizácií'; cs = 'Windows Update – oprava služby aktualizací' }
    'BITS'               = @{ sk = 'prenos súborov na pozadí (aktualizácie, Store)'; cs = 'přenos souborů na pozadí (aktualizace, Store)' }
    'DoSvc'              = @{ sk = 'Delivery Optimization – doručovanie aktualizácií, aj od iných počítačov'; cs = 'Delivery Optimization – doručování aktualizací, i z jiných počítačů' }
    'CryptSvc'           = @{ sk = 'kryptografické služby – sťahuje zoznamy dôveryhodných certifikátov; zámerne nešifrovane (port 80), lebo certifikáty sú podpísané'; cs = 'kryptografické služby – stahuje seznamy důvěryhodných certifikátů; záměrně nešifrovaně (port 80), protože certifikáty jsou podepsané' }
    'WpnService'         = @{ sk = 'push oznámenia Windows'; cs = 'push notifikace Windows' }
    'WpnUserService'     = @{ sk = 'push oznámenia Windows (pre prihláseného používateľa)'; cs = 'push notifikace Windows (pro přihlášeného uživatele)' }
    'Dnscache'           = @{ sk = 'DNS klient – prekladá mená domén na adresy'; cs = 'DNS klient – překládá jména domén na adresy' }
    'NlaSvc'             = @{ sk = 'zisťovanie, či je počítač pripojený na internet'; cs = 'zjišťování, zda je počítač připojený k internetu' }
    'wlidsvc'            = @{ sk = 'prihlásenie do konta Microsoft'; cs = 'přihlášení k účtu Microsoft' }
    'CDPSvc'             = @{ sk = 'prepojenie zariadení (zdieľanie medzi tvojimi zariadeniami)'; cs = 'propojení zařízení (sdílení mezi tvými zařízeními)' }
    'CDPUserSvc'         = @{ sk = 'prepojenie zariadení (pre prihláseného používateľa)'; cs = 'propojení zařízení (pro přihlášeného uživatele)' }
    'OneSyncSvc'         = @{ sk = 'synchronizácia pošty, kontaktov a kalendára'; cs = 'synchronizace pošty, kontaktů a kalendáře' }
    'LanmanWorkstation'  = @{ sk = 'sieťové zdieľanie súborov (SMB)'; cs = 'sdílení souborů v síti (SMB)' }
    'iphlpsvc'           = @{ sk = 'IP pomocník – IPv6 tunelovanie'; cs = 'IP pomocník – tunelování IPv6' }
    'Schedule'           = @{ sk = 'Plánovač úloh'; cs = 'Plánovač úloh' }
    'TokenBroker'        = @{ sk = 'správa prihlásenia aplikácií Store'; cs = 'správa přihlášení aplikací Store' }
    'InstallService'     = @{ sk = 'inštalácia aplikácií Store'; cs = 'instalace aplikací Store' }
    'StorSvc'            = @{ sk = 'úložisko – aj overovanie licencií Store'; cs = 'úložiště – i ověřování licencí Store' }
    'ClipSVC'            = @{ sk = 'licencie aplikácií Store'; cs = 'licence aplikací Store' }
    'LicenseManager'     = @{ sk = 'licencie Windows a Store'; cs = 'licence Windows a Store' }
    'WSearch'            = @{ sk = 'indexovanie vyhľadávania'; cs = 'indexování vyhledávání' }
    'Winmgmt'            = @{ sk = 'správa Windows (WMI)'; cs = 'správa Windows (WMI)' }
    'WlanSvc'            = @{ sk = 'Wi-Fi'; cs = 'Wi-Fi' }
    'TimeBrokerSvc'      = @{ sk = 'časové úlohy aplikácií na pozadí'; cs = 'časové úlohy aplikací na pozadí' }
    'W32Time'            = @{ sk = 'synchronizácia času'; cs = 'synchronizace času' }
    'DusmSvc'            = @{ sk = 'meranie spotreby dát'; cs = 'měření spotřeby dat' }
    'SysMain'            = @{ sk = 'predbežné načítavanie aplikácií'; cs = 'předběžné načítání aplikací' }
    'wscsvc'             = @{ sk = 'Centrum zabezpečenia'; cs = 'Centrum zabezpečení' }
    'WdiServiceHost'     = @{ sk = 'diagnostika Windows'; cs = 'diagnostika Windows' }
    'PcaSvc'             = @{ sk = 'asistent kompatibility programov'; cs = 'asistent kompatibility programů' }
    'SSDPSRV'            = @{ sk = 'vyhľadávanie zariadení v sieti (UPnP)'; cs = 'vyhledávání zařízení v síti (UPnP)' }
    'WinHttpAutoProxySvc'= @{ sk = 'automatické zisťovanie proxy (WPAD)'; cs = 'automatické zjišťování proxy (WPAD)' }
    'NcbService'         = @{ sk = 'sprostredkovateľ sieťových spojení pre aplikácie Store'; cs = 'prostředník síťových spojení pro aplikace Store' }
    'Tailscale'          = @{ sk = 'Tailscale – súkromná VPN sieť medzi tvojimi zariadeniami'; cs = 'Tailscale – soukromá VPN síť mezi tvými zařízeními' }
}

# Slovník portov: číslo → čo znamená (sk, cs)
$SlovnikPortov = @{
    '443'   = @{ sk = 'HTTPS – šifrované'; cs = 'HTTPS – šifrované' }
    '80'    = @{ sk = 'HTTP – NEŠIFROVANÉ'; cs = 'HTTP – NEŠIFROVANÉ' }
    '53'    = @{ sk = 'DNS'; cs = 'DNS' }
    '853'   = @{ sk = 'DNS cez TLS – šifrované'; cs = 'DNS přes TLS – šifrované' }
    '5228'  = @{ sk = 'Google push oznámenia'; cs = 'Google push notifikace' }
    '5229'  = @{ sk = 'Google push oznámenia'; cs = 'Google push notifikace' }
    '5230'  = @{ sk = 'Google push oznámenia'; cs = 'Google push notifikace' }
    '4070'  = @{ sk = 'Spotify'; cs = 'Spotify' }
    '993'   = @{ sk = 'IMAP pošta – šifrovaná'; cs = 'IMAP e-mail – šifrovaný' }
    '995'   = @{ sk = 'POP3 pošta – šifrovaná'; cs = 'POP3 e-mail – šifrovaný' }
    '587'   = @{ sk = 'odosielanie pošty'; cs = 'odesílání e-mailu' }
    '465'   = @{ sk = 'odosielanie pošty – šifrované'; cs = 'odesílání e-mailu – šifrované' }
    '22'    = @{ sk = 'SSH'; cs = 'SSH' }
    '3478'  = @{ sk = 'STUN/TURN – hovory a video'; cs = 'STUN/TURN – hovory a video' }
    '8883'  = @{ sk = 'MQTT – šifrované'; cs = 'MQTT – šifrované' }
    '1194'  = @{ sk = 'OpenVPN'; cs = 'OpenVPN' }
    '51820' = @{ sk = 'WireGuard VPN'; cs = 'WireGuard VPN' }
    '27015' = @{ sk = 'Steam / herné servery'; cs = 'Steam / herní servery' }
}

# ============================================================================
#  POMOCNÉ FUNKCIE
# ============================================================================

# Opýta sa používateľa na jazyk reportu. Enter = slovenčina.
function Select-Jazyk {
    while ($true) {
        $odpoved = ''
        try { $odpoved = [string](Read-Host '  Jazyk reportu (1 = Slovensky, 2 = Cesky, Enter = 1)') } catch { return 'sk' }
        $odpoved = $odpoved.Trim().ToLower()
        if ($odpoved -eq '' -or $odpoved -eq '1' -or $odpoved -eq 'sk') { return 'sk' }
        if ($odpoved -eq '2' -or $odpoved -eq 'cs' -or $odpoved -eq 'cz') { return 'cs' }
    }
}

# Porovná dva jazykové bloky: rovnaké kľúče a žiadny prázdny text. Chyby zbiera do $script:ChybyPrekladov.
function Compare-Kluce {
    param($A, $B, [string]$Cesta)
    foreach ($k in $A.Keys) {
        $c = if ($Cesta) { $Cesta + '.' + $k } else { [string]$k }
        if (-not $B.ContainsKey($k)) { $script:ChybyPrekladov += $c; continue }
        if ($A[$k] -is [hashtable]) {
            if ($B[$k] -is [hashtable]) { Compare-Kluce $A[$k] $B[$k] $c } else { $script:ChybyPrekladov += $c }
        } elseif ([string]::IsNullOrWhiteSpace([string]$B[$k]) -or [string]::IsNullOrWhiteSpace([string]$A[$k])) {
            $script:ChybyPrekladov += $c
        }
    }
    foreach ($k in $B.Keys) {
        if (-not $A.ContainsKey($k)) {
            $script:ChybyPrekladov += $(if ($Cesta) { $Cesta + '.' + $k } else { [string]$k })
        }
    }
}

# Overí, že každý text existuje v oboch jazykoch (bloky $TL aj slovníky).
function Test-Preklady {
    $script:ChybyPrekladov = @()
    Compare-Kluce $TL['sk'] $TL['cs'] ''
    foreach ($z in ($SlovnikDomen + $SlovnikIP)) {
        if ([string]::IsNullOrWhiteSpace([string]$z.sk) -or [string]::IsNullOrWhiteSpace([string]$z.cs)) { $script:ChybyPrekladov += ('slovnik: ' + $z.Vzor) }
    }
    foreach ($tab in @($SlovnikProgramov, $SlovnikSluzieb, $SlovnikPortov)) {
        foreach ($k in $tab.Keys) {
            if ([string]::IsNullOrWhiteSpace([string]$tab[$k].sk) -or [string]::IsNullOrWhiteSpace([string]$tab[$k].cs)) { $script:ChybyPrekladov += ('slovnik: ' + $k) }
        }
    }
    return $script:ChybyPrekladov
}

# Prečíta hodnotu z registrov. Ak kľúč alebo hodnota chýba, vráti $null.
function Get-RegValue {
    param([string]$Cesta, [string]$Meno)
    try {
        $p = Get-ItemProperty -Path $Cesta -Name $Meno -ErrorAction Stop
        return $p.$Meno
    } catch {
        return $null
    }
}

# Vytvorí jednu položku reportu časti A z textov položky $P (Nazov, Kon, Co, Kde).
function New-Polozka {
    param($P, [string]$Stav, [string]$Zistene)
    return [pscustomobject]@{
        Nazov   = $P.Nazov
        Kon     = $P.Kon
        Stav    = $Stav      # OK | POSIELA | ZAPNUTE | NEZISTENE
        Zistene = $Zistene
        Co      = $P.Co
        Kde     = $P.Kde
    }
}

# HTML-escape textu.
function Enc {
    param($s)
    if ($null -eq $s) { return '' }
    return [System.Net.WebUtility]::HtmlEncode([string]$s)
}

# Je adresa lokálna (nie internet)?
function Test-Lokalna {
    param([string]$Ip)
    if ([string]::IsNullOrWhiteSpace($Ip)) { return $true }
    if ($Ip -eq '0.0.0.0' -or $Ip -eq '::' -or $Ip -eq '::1') { return $true }
    if ($Ip -like '127.*' -or $Ip -like '10.*' -or $Ip -like '192.168.*') { return $true }
    if ($Ip -like 'fe80*' -or $Ip -like 'fc*' -or $Ip -like 'fd*') { return $true }
    if ($Ip -match '^172\.(1[6-9]|2[0-9]|3[01])\.') { return $true }
    if ($Ip -like '169.254.*') { return $true }
    if ($Ip -like '100.*') {   # Tailscale / CGNAT rozsah 100.64.0.0/10
        if ($Ip -match '^100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.') { return $true }
    }
    return $false
}

# Vysvetlenie domény zo slovníka. Vráti @{ Typ; Text } v zvolenom jazyku.
function Get-VyznamDomeny {
    param([string]$Domena, [bool]$JeIP)
    if ($JeIP) {
        foreach ($r in $SlovnikIP) {
            if ($Domena -match $r.Vzor) { return @{ Typ = $r.Typ; Text = ($T.IPRozsah + $r[$Jazyk]) } }
        }
        if ($Mena) { return @{ Typ = 'nezname'; Text = $T.IbaIPRev } }
        return @{ Typ = 'nezname'; Text = $T.IbaIP }
    }
    foreach ($z in $SlovnikDomen) {
        if ($Domena -like $z.Vzor -or $Domena -eq ($z.Vzor -replace '^\*\.', '')) {
            return @{ Typ = $z.Typ; Text = $z[$Jazyk] }
        }
    }
    return @{ Typ = 'nezname'; Text = $T.Nezname }
}

# Vysvetlenie služby (odstráni príponu _xxxx pri službách na používateľa).
function Get-VyznamSluzby {
    param([string]$Meno)
    if ($SlovnikSluzieb.ContainsKey($Meno)) { return $SlovnikSluzieb[$Meno][$Jazyk] }
    $zaklad = $Meno -replace '_[0-9a-fA-F]+$', ''
    if ($SlovnikSluzieb.ContainsKey($zaklad)) { return $SlovnikSluzieb[$zaklad][$Jazyk] }
    return $null
}

# ============================================================================
#  ŠTART
# ============================================================================
if ($Sekundy -lt $Krok) { $Sekundy = $Krok }

# Jazyk reportu: z prepínača, inak sa KONTRA opýta (cz sa berie ako cs).
if ($PSBoundParameters.ContainsKey('Jazyk')) {
    $Jazyk = $Jazyk.ToLower()
    if ($Jazyk -eq 'cz') { $Jazyk = 'cs' }
} else {
    Write-Host ''
    $Jazyk = Select-Jazyk
}

# Kontrola, že chýba niektorý preklad; bez nej by report mal diery v texte.
$chybyPrekladov = @(Test-Preklady)
if ($chybyPrekladov.Count -gt 0) {
    Write-Host ('  CHYBA: chybaju preklady: ' + ($chybyPrekladov -join ', ')) -ForegroundColor Red
    exit 1
}
$T = $TL[$Jazyk]

Write-Host ''
Write-Host ('  {0}  -  {1}  -  {2}' -f $T.Nazov, $T.Slogan, $T.KonzolaSpec) -ForegroundColor Cyan
Write-Host ('  ' + $T.KonzolaUvod) -ForegroundColor DarkGray
Write-Host ''

# Informácie o systéme (iba čítanie)
$os  = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
$nt  = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
$edicia         = if ($nt.EditionID) { [string]$nt.EditionID } else { $T.EdiciaNezname }
$verziaDisplay  = if ($nt.DisplayVersion) { [string]$nt.DisplayVersion } else { '' }
$build          = if ($os.BuildNumber) { [string]$os.BuildNumber } else { '' }
if ($nt.UBR -ne $null -and $build) { $build = '{0}.{1}' -f $build, $nt.UBR }
$osCaption      = if ($os.Caption) { [string]$os.Caption } else { 'Windows' }
$jeEnterprise   = $edicia -match 'Enterprise|Education'

$jeAdmin = $false
try {
    $identita = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identita)
    $jeAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { $jeAdmin = $false }

# ============================================================================
#  ČASŤ A  –  nastavenia súkromia (iba čítanie registrov, služieb a úloh)
# ============================================================================
Write-Host ('  ' + $T.KonzolaCastA) -ForegroundColor White
$polozky = @()

# --- 1. Úroveň diagnostických údajov -----------------------------------------
$p = $T.Polozka.Telemetria
$polTel = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'
$curTel = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry'
$tel = $null
if ($null -ne $polTel) { $tel = [int]$polTel } elseif ($null -ne $curTel) { $tel = [int]$curTel }

if ($null -eq $tel) {
    $polozky += New-Polozka $p 'POSIELA' $p.Chyba
} elseif ($tel -eq 0) {
    if ($jeEnterprise) { $polozky += New-Polozka $p 'OK' $p.U0 }
    else               { $polozky += New-Polozka $p 'OK' ($p.U0Pro -f $edicia) }
} elseif ($tel -eq 1) {
    $polozky += New-Polozka $p 'OK' ($p.U1 -f $edicia)
} elseif ($tel -eq 2) {
    $polozky += New-Polozka $p 'POSIELA' $p.U2
} else {
    $polozky += New-Polozka $p 'POSIELA' $p.U3
}

# --- 2. Služba DiagTrack ------------------------------------------------------
$p = $T.Polozka.DiagTrack
$svc = Get-Service -Name 'DiagTrack' -ErrorAction SilentlyContinue
if ($null -eq $svc) {
    $polozky += New-Polozka $p 'NEZISTENE' $p.Chyba
} else {
    $start = [string]$svc.StartType
    if ($svc.Status -eq 'Running') {
        $polozky += New-Polozka $p 'POSIELA' ($p.Bezi -f $start)
    } elseif ($start -eq 'Disabled') {
        $polozky += New-Polozka $p 'OK' $p.Vypnuta
    } else {
        $polozky += New-Polozka $p 'POSIELA' ($p.Stoji -f $start)
    }
}

# --- 3. Plánované úlohy -------------------------------------------------------
$p = $T.Polozka.Ulohy
$ulohy = @()
try { $ulohy += Get-ScheduledTask -TaskPath '\Microsoft\Windows\Application Experience\' -ErrorAction Stop } catch { }
try { $ulohy += Get-ScheduledTask -TaskPath '\Microsoft\Windows\Customer Experience Improvement Program\' -ErrorAction Stop } catch { }
if ($ulohy.Count -eq 0) {
    $polozky += New-Polozka $p 'NEZISTENE' $p.Ziadne
} else {
    $zapnute = @($ulohy | Where-Object { [string]$_.State -ne 'Disabled' } | ForEach-Object { $_.TaskName })
    if ($zapnute.Count -gt 0) {
        $polozky += New-Polozka $p 'POSIELA' ($p.Zapnute -f ($zapnute -join ', '))
    } else {
        $polozky += New-Polozka $p 'OK' ($p.Vypnute -f (($ulohy | ForEach-Object { $_.TaskName }) -join ', '))
    }
}

# --- 4. Reklamné ID -----------------------------------------------------------
$p = $T.Polozka.Reklama
$adv = Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled'
if ($null -eq $adv)      { $polozky += New-Polozka $p 'POSIELA' $p.Chyba }
elseif ([int]$adv -eq 0) { $polozky += New-Polozka $p 'OK'      $p.Vyp }
else                     { $polozky += New-Polozka $p 'POSIELA' $p.Zap }

# --- 5. Prispôsobené prostredie ----------------------------------------------
$p = $T.Polozka.Prisposobene
$tail = Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled'
if ($null -eq $tail)      { $polozky += New-Polozka $p 'POSIELA' $p.Chyba }
elseif ([int]$tail -eq 0) { $polozky += New-Polozka $p 'OK'      $p.Vyp }
else                      { $polozky += New-Polozka $p 'POSIELA' $p.Zap }

# --- 6. História aktivít -------------------------------------------------------
$p = $T.Polozka.Aktivity
$pub = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities'
$upl = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities'
if ($null -eq $pub -and $null -eq $upl) {
    $polozky += New-Polozka $p 'POSIELA' $p.Chyba
} elseif (($null -ne $pub -and [int]$pub -eq 0) -and ($null -eq $upl -or [int]$upl -eq 0)) {
    $polozky += New-Polozka $p 'OK' $p.Vyp
} else {
    $sPub = if ($null -eq $pub) { $T.SlovoPredvolene } elseif ([int]$pub -eq 0) { $T.SlovoVypnute } else { $T.SlovoZapnute }
    $sUpl = if ($null -eq $upl) { $T.SlovoPredvolene } elseif ([int]$upl -eq 0) { $T.SlovoVypnute } else { $T.SlovoZapnute }
    $polozky += New-Polozka $p 'POSIELA' ($p.Zap -f $sPub, $sUpl)
}

# --- 7. Recall ----------------------------------------------------------------
# Overená je iba politika (HKCU/HKLM Policies\WindowsAI). Používateľský kľúč
# (CurrentVersion\WindowsAI) sa nečíta, pretože nie je overený: ak politika Recall
# nevypína a AI komponent je prítomný, položka je ⚪ a posiela používateľa do Nastavení.
$p = $T.Polozka.Recall
$recPol = Get-RegValue 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis'
if ($null -eq $recPol) { $recPol = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' }
$aixPritomny = $false
try { $aixPritomny = (Test-Path (Join-Path $env:windir 'SystemApps\MicrosoftWindows.Client.AIX_cw5n1h2txyewy')) } catch { $aixPritomny = $false }
if ($null -ne $recPol -and [int]$recPol -eq 1) {
    $polozky += New-Polozka $p 'OK' $p.VypPolitika
} elseif (-not $aixPritomny) {
    $polozky += New-Polozka $p 'OK' $p.Nepritomny
} else {
    $polozky += New-Polozka $p 'NEZISTENE' $p.Pritomny
}

foreach ($pol in $polozky) {
    $farba = switch ($pol.Stav) { 'OK' { 'Green' } 'POSIELA' { 'Yellow' } 'ZAPNUTE' { 'Yellow' } default { 'DarkGray' } }
    Write-Host ('    [{0,-10}] {1}' -f $T.Stav[$pol.Stav].Kon, $pol.Kon) -ForegroundColor $farba
}

# ============================================================================
#  ČASŤ B  –  kto práve komunikuje s internetom (iba čítanie)
# ============================================================================
Write-Host ''
Write-Host ('  ' + ($T.KonzolaCastB -f $Sekundy)) -ForegroundColor White

$vzoriek  = [int][math]::Ceiling($Sekundy / $Krok)
$zachyty  = @{}   # kľúč "pid|ip|port" -> @{ <číslo vzorky> = počet spojení v tej vzorke }
$dnsMapa  = @{}   # ip -> meno domény (iba z lokálnej DNS pamäte)
$revMapa  = @{}   # ip -> meno zo spätného DNS (iba s -Mena)
$procMapa = @{}   # pid -> meno procesu
$svcMapa  = @{}   # pid -> zoznam služieb

# Služby podľa PID (snímka na začiatku, doplní sa na konci)
function Add-Sluzby {
    $sl = Get-CimInstance -ClassName Win32_Service -Filter 'ProcessId != 0' -ErrorAction SilentlyContinue
    foreach ($s in $sl) {
        $k = [string]$s.ProcessId
        if (-not $svcMapa.ContainsKey($k)) { $svcMapa[$k] = @() }
        if ($svcMapa[$k] -notcontains $s.Name) { $svcMapa[$k] += $s.Name }
    }
}
Add-Sluzby

for ($i = 1; $i -le $vzoriek; $i++) {
    $spoj = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue
    foreach ($c in $spoj) {
        $ip = [string]$c.RemoteAddress
        if (Test-Lokalna $ip) { continue }
        $k = '{0}|{1}|{2}' -f $c.OwningProcess, $ip, $c.RemotePort
        if (-not $zachyty.ContainsKey($k)) { $zachyty[$k] = @{} }
        if ($zachyty[$k].ContainsKey($i)) { $zachyty[$k][$i]++ } else { $zachyty[$k][$i] = 1 }

        $pidK = [string]$c.OwningProcess
        if (-not $procMapa.ContainsKey($pidK)) {
            $pr = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
            if ($pr) { $procMapa[$pidK] = $pr.ProcessName } else { $procMapa[$pidK] = $T.ProcesUkonceny }
        }
    }

    # DNS pamäť: iba čítanie, žiadne nové dopyty
    $cache = Get-DnsClientCache -ErrorAction SilentlyContinue
    foreach ($z in $cache) {
        $d = [string]$z.Data
        if ($d -and ($d -match '^\d{1,3}(\.\d{1,3}){3}$' -or $d -match ':')) {
            if (-not $dnsMapa.ContainsKey($d)) { $dnsMapa[$d] = [string]$z.Entry }
        }
    }

    Write-Progress -Activity $T.Nazov -Status ($T.KonzolaVzorka -f $i, $vzoriek, $zachyty.Count) -PercentComplete ([int](100 * $i / $vzoriek))
    if ($i -lt $vzoriek) { Start-Sleep -Seconds $Krok }
}
Write-Progress -Activity $T.Nazov -Completed
Add-Sluzby

# --- voliteľný spätný DNS (iba s -Mena) ---------------------------------------
if ($Mena) {
    $bezMena = @{}
    foreach ($k in $zachyty.Keys) {
        $ip = $k.Split('|')[1]
        if (-not $dnsMapa.ContainsKey($ip)) { $bezMena[$ip] = $true }
    }
    $ipZoznam = @($bezMena.Keys)
    Write-Host ('  ' + ($T.KonzolaMena -f $ipZoznam.Count)) -ForegroundColor White
    $n = 0
    foreach ($ip in $ipZoznam) {
        $n++
        Write-Progress -Activity ($T.Nazov + ' -Mena') -Status $ip -PercentComplete ([int](100 * $n / [math]::Max(1, $ipZoznam.Count)))
        if ($ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { continue }   # iba IPv4
        $arpa = (($ip.Split('.'))[3..0] -join '.') + '.in-addr.arpa'
        try {
            $odp = Resolve-DnsName -Name $arpa -Type PTR -DnsOnly -QuickTimeout -ErrorAction Stop
            $ptr = @($odp | Where-Object { $_.Type -eq 'PTR' -and $_.NameHost } | Select-Object -First 1)
            if ($ptr.Count -gt 0) { $revMapa[$ip] = ([string]$ptr[0].NameHost).TrimEnd('.') }
        } catch { }
    }
    Write-Progress -Activity ($T.Nazov + ' -Mena') -Completed
    Write-Host ($T.KonzolaMenaOk -f $revMapa.Count, $ipZoznam.Count) -ForegroundColor DarkGray
}

# --- zoskupenie: program -> cieľ ------------------------------------------------
$programy = @{}
foreach ($k in $zachyty.Keys) {
    $casti = $k.Split('|')
    $pidK  = $casti[0]; $ip = $casti[1]; $port = $casti[2]
    $meno  = if ($procMapa.ContainsKey($pidK)) { $procMapa[$pidK] } else { $T.ProcesUkonceny }
    $sluzby = @()
    if ($svcMapa.ContainsKey($pidK)) { $sluzby = $svcMapa[$pidK] }

    $progK = $meno
    if ($meno -eq 'svchost' -and $sluzby.Count -gt 0) { $progK = 'svchost (' + ($sluzby -join ', ') + ')' }

    if (-not $programy.ContainsKey($progK)) {
        $programy[$progK] = @{ Meno = $meno; Sluzby = $sluzby; Ciele = @{}; VzorkySucet = @{} }
    }

    $zdroj = 'ip'
    if ($dnsMapa.ContainsKey($ip))     { $ciel = $dnsMapa[$ip]; $zdroj = 'cache' }
    elseif ($revMapa.ContainsKey($ip)) { $ciel = $revMapa[$ip]; $zdroj = 'rev' }
    else                               { $ciel = $ip }

    $cielK = '{0}|{1}' -f $ciel, $port
    if (-not $programy[$progK].Ciele.ContainsKey($cielK)) {
        $programy[$progK].Ciele[$cielK] = @{ Ciel = $ciel; Port = $port; Zdroj = $zdroj; IP = $ip; Vzorky = @{} }
    }
    foreach ($vz in $zachyty[$k].Keys) {
        $cnt = $zachyty[$k][$vz]
        $cv = $programy[$progK].Ciele[$cielK].Vzorky
        if ($cv.ContainsKey($vz)) { $cv[$vz] += $cnt } else { $cv[$vz] = $cnt }
        $pv = $programy[$progK].VzorkySucet
        if ($pv.ContainsKey($vz)) { $pv[$vz] += $cnt } else { $pv[$vz] = $cnt }
    }
}

# Súhrnné čísla
$pocetCielov = 0; $pocetTel = 0; $pocetBezMena = 0
foreach ($pg in $programy.Values) {
    foreach ($c in $pg.Ciele.Values) {
        $pocetCielov++
        if ($c.Zdroj -eq 'ip') { $pocetBezMena++ }
        $vz = Get-VyznamDomeny -Domena $c.Ciel -JeIP ($c.Zdroj -eq 'ip')
        if ($vz.Typ -eq 'telemetria' -or $vz.Typ -eq 'analytika') { $pocetTel++ }
    }
}
$pocetWarnA = @($polozky | Where-Object { $_.Stav -eq 'POSIELA' -or $_.Stav -eq 'ZAPNUTE' }).Count
Write-Host ('    ' + ($T.KonzolaSuhrn -f $programy.Count, $pocetCielov)) -ForegroundColor DarkGray

# ============================================================================
#  REPORT  –  jeden samostatný HTML súbor, bez externých zdrojov
# ============================================================================
$css = @'
:root{--bg:#070b16;--bg2:#0d1630;--panel:#101c3a;--line:#223466;--txt:#e6ecff;--mut:#9fb0d8;--acc:#3385ff;--ok:#2ecc71;--warn:#f39c12;--na:#8b97b8;--tel:#ff6b6b;--viol:#9b6dff}
*{box-sizing:border-box}body{margin:0;background:linear-gradient(180deg,#000 0%,var(--bg) 25%,var(--bg2) 100%);color:var(--txt);font:15px/1.55 Segoe UI,system-ui,sans-serif;min-height:100vh}
.wrap{max-width:1100px;margin:0 auto;padding:28px 18px 60px}
header{border:1px solid var(--line);border-radius:14px;padding:22px 26px;background:rgba(16,28,58,.75);margin-bottom:18px}
h1{margin:0;font-size:34px;letter-spacing:.06em}h1 small{font-size:16px;letter-spacing:0;color:var(--acc);margin-left:14px;font-weight:500}
.spec{color:var(--mut);margin:4px 0 10px}.sub{margin:0 0 14px;color:var(--txt)}
.meta{display:flex;flex-wrap:wrap;gap:8px 22px;color:var(--mut);font-size:13px}.meta b{color:var(--txt);font-weight:600}
.verdikt{display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px;margin:0 0 14px}
.verdikt div{border:1px solid var(--line);border-radius:10px;background:var(--panel);padding:12px 16px;font-size:14px}
.verdikt .n{display:block;font-size:30px;font-weight:700;line-height:1.1;margin-bottom:4px}
.verdikt .warn .n{color:var(--warn)}.verdikt .tel .n{color:var(--tel)}.verdikt .acc .n{color:var(--acc)}.verdikt .ok .n{color:var(--ok)}
.tip{border:1px solid var(--viol);border-radius:10px;background:rgba(155,109,255,.08);padding:14px 18px;margin:0 0 18px}
.tip .warnl{margin:10px 0 0;color:var(--warn);font-weight:600}
.nav{color:var(--mut);font-size:13px;margin:0 0 8px}
.tip b{display:block;color:var(--viol);margin-bottom:4px;font-size:15px}
h2{font-size:20px;margin:30px 0 12px;color:var(--acc)}
.legend{display:flex;flex-wrap:wrap;gap:8px 20px;font-size:13px;color:var(--mut);margin-bottom:6px}
.card{border:1px solid var(--line);border-left-width:5px;border-radius:10px;background:var(--panel);padding:14px 18px;margin:10px 0}
.card.ok{border-left-color:var(--ok)}.card.warn{border-left-color:var(--warn)}.card.na{border-left-color:var(--na)}
.card .h{display:flex;align-items:center;gap:10px;font-size:17px;font-weight:600}
.card .st{font-size:13px;font-weight:500;padding:2px 9px;border-radius:999px;border:1px solid var(--line);color:var(--mut)}
.card.ok .st{color:var(--ok);border-color:var(--ok)}.card.warn .st{color:var(--warn);border-color:var(--warn)}
.row{margin-top:8px;font-size:14px}.row b{color:var(--mut);font-weight:600;margin-right:6px}
.prog{border:1px solid var(--line);border-radius:10px;background:var(--panel);padding:14px 18px;margin:10px 0}
.prog .h{display:flex;flex-wrap:wrap;align-items:baseline;gap:10px}.prog .h .n{font-size:17px;font-weight:600}.prog .h .c{color:var(--mut);font-size:13px}
.prog .d{color:var(--mut);font-size:14px;margin:4px 0 8px}
table{width:100%;border-collapse:collapse;font-size:14px}th{text-align:left;color:var(--mut);font-weight:600;padding:6px 8px;border-bottom:1px solid var(--line)}td{padding:6px 8px;border-bottom:1px solid rgba(34,52,102,.5);vertical-align:top}
.ip{color:var(--mut)}.pn{color:var(--mut);font-size:12px}.p80{color:var(--warn)}
.b{display:inline-block;font-size:11px;letter-spacing:.05em;padding:1px 7px;border-radius:5px;margin-right:7px;border:1px solid var(--line);color:var(--mut);vertical-align:1px;white-space:nowrap}
.b.telemetria,.b.analytika{color:var(--tel);border-color:var(--tel)}.b.aktualizacie{color:var(--acc);border-color:var(--acc)}.b.nezname{opacity:.7}.b.rev{color:var(--viol);border-color:var(--viol);margin-left:6px}
.empty{color:var(--mut);padding:14px 18px;border:1px dashed var(--line);border-radius:10px}
footer{margin-top:36px;border-top:1px solid var(--line);padding-top:16px;color:var(--mut);font-size:13px}footer .big{color:var(--txt);font-size:16px;font-weight:600;margin-bottom:6px}footer div{margin-bottom:6px}
@media(max-width:700px){.verdikt{grid-template-columns:1fr}h1 small{display:block;margin:6px 0 0}}
'@

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('<!DOCTYPE html><html lang="' + $Jazyk + '"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">')
[void]$sb.Append('<title>' + (Enc $T.ReportTitul) + '</title><style>' + $css + '</style></head><body><div class="wrap">')

# hlavička
$datum = Get-Date -Format 'd. M. yyyy, HH:mm'
$winText = '{0} · {1} · build {2}' -f $osCaption, $verziaDisplay, $build
$pravaText = if ($jeAdmin) { $T.PravaAdmin } else { $T.PravaBezAdmin }
$menaText  = if ($Mena) { $T.MenaRev } else { $T.MenaLokalne }
[void]$sb.Append('<header><h1>' + (Enc $T.Nazov) + '<small>' + (Enc $T.Slogan) + '</small></h1>')
[void]$sb.Append('<div class="spec">' + (Enc $T.Spec) + '</div><p class="sub">' + (Enc $T.ReportPodtitul) + '</p>')
[void]$sb.Append('<div class="meta"><span><b>' + (Enc $T.MetaDatum) + ':</b> ' + (Enc $datum) + '</span>')
[void]$sb.Append('<span><b>' + (Enc $T.MetaWindows) + ':</b> ' + (Enc $winText) + '</span>')
[void]$sb.Append('<span><b>' + (Enc $T.MetaSken) + ':</b> ' + $Sekundy + ' s (' + (Enc $T.MetaVzorky) + ': ' + $vzoriek + ')</span>')
[void]$sb.Append('<span><b>' + (Enc $T.MetaPrava) + ':</b> ' + (Enc $pravaText) + '</span>')
[void]$sb.Append('<span><b>' + (Enc $T.MetaMena) + ':</b> ' + (Enc $menaText) + '</span></div></header>')

# verdikt: veľké číslo + popis, ktorý sa nesklonuje (začína slovom „Počet“)
$vA = $T.VerdiktA -f $polozky.Count
$vB = $T.VerdiktB -f $pocetCielov
$vT = $T.VerdiktTel -f $pocetBezMena
$cssA = if ($pocetWarnA -gt 0) { 'warn' } else { 'ok' }
$cssT = if ($pocetTel -gt 0) { 'tel' } else { 'ok' }
[void]$sb.Append('<div class="verdikt"><div class="' + $cssA + '"><span class="n">' + $pocetWarnA + '</span>' + (Enc $vA) + '</div>')
[void]$sb.Append('<div class="acc"><span class="n">' + $programy.Count + '</span>' + (Enc $vB) + '</div>')
[void]$sb.Append('<div class="' + $cssT + '"><span class="n">' + $pocetTel + '</span>' + (Enc $vT) + '</div></div>')

# tip: pošli to svojej AI
[void]$sb.Append('<div class="tip"><b>' + (Enc $T.TipNadpis) + '</b>' + (Enc $T.TipText) + '<p class="warnl">' + (Enc $T.TipPozor) + '</p></div>')

# legenda
[void]$sb.Append('<div class="legend"><span>' + $T.Stav.OK.Ikona + ' ' + (Enc $T.LegendaOK) + '</span>')
[void]$sb.Append('<span>' + $T.Stav.POSIELA.Ikona + ' ' + (Enc $T.LegendaPosiela) + '</span>')
[void]$sb.Append('<span>' + $T.Stav.NEZISTENE.Ikona + ' ' + (Enc $T.LegendaNezistene) + '</span></div>')

# časť A
[void]$sb.Append('<h2>' + (Enc $T.SekciaA) + '</h2><p class="nav">' + (Enc $T.PoznamkaNavigacia) + '</p>')
foreach ($pol in $polozky) {
    $st = $T.Stav[$pol.Stav]
    [void]$sb.Append('<div class="card ' + $st.Css + '"><div class="h"><span>' + $st.Ikona + '</span><span>' + (Enc $pol.Nazov) + '</span><span class="st">' + (Enc $st.Text) + '</span></div>')
    [void]$sb.Append('<div class="row"><b>' + (Enc $T.Zistene) + ':</b>' + (Enc $pol.Zistene) + '</div>')
    [void]$sb.Append('<div class="row"><b>' + (Enc $T.CoToZnamena) + ':</b>' + (Enc $pol.Co) + '</div>')
    [void]$sb.Append('<div class="row"><b>' + (Enc $T.KdeToNajdem) + ':</b>' + (Enc $pol.Kde) + '</div></div>')
}

# časť B
[void]$sb.Append('<h2>' + (Enc $T.SekciaB) + '</h2>')
if ($programy.Count -eq 0) {
    [void]$sb.Append('<div class="empty">' + (Enc ($T.SuhrnBNic -f $Sekundy)) + '</div>')
} else {
    [void]$sb.Append('<p>' + (Enc ($T.SuhrnB -f $Sekundy, $programy.Count, $pocetCielov, $Krok, $vzoriek)) + '</p>')
    # program: koľko vzoriek a maximálne koľko spojení naraz
    foreach ($pg in $programy.Values) {
        $pg.VzorkyPocet = $pg.VzorkySucet.Count
        $m = 0; foreach ($v in $pg.VzorkySucet.Values) { if ($v -gt $m) { $m = $v } }
        $pg.Naraz = $m
    }
    $zoradene = $programy.GetEnumerator() | Sort-Object @{ e = { $_.Value.VzorkyPocet }; Descending = $true }, @{ e = { $_.Value.Naraz }; Descending = $true }
    foreach ($e in $zoradene) {
        $pg = $e.Value
        $vysvProg = $null
        if ($SlovnikProgramov.ContainsKey($pg.Meno)) { $vysvProg = $SlovnikProgramov[$pg.Meno][$Jazyk] }
        if ($null -eq $vysvProg) { $vysvProg = $T.Nezname }
        $hlav = ($T.VzorkyText -f $pg.VzorkyPocet, $vzoriek) + ' · ' + ($T.NarazText -f $pg.Naraz)

        [void]$sb.Append('<div class="prog"><div class="h"><span class="n">' + (Enc $pg.Meno) + '</span><span class="c">' + (Enc $hlav) + '</span></div>')
        [void]$sb.Append('<div class="d">' + (Enc $vysvProg) + '</div>')
        if ($pg.Sluzby.Count -gt 0) {
            $slText = @()
            foreach ($s in $pg.Sluzby) {
                $v = Get-VyznamSluzby $s
                if ($v) { $slText += ('<b>' + (Enc $s) + '</b> – ' + (Enc $v)) } else { $slText += ('<b>' + (Enc $s) + '</b>') }
            }
            [void]$sb.Append('<div class="row"><b>' + (Enc $T.Sluzby) + ':</b>' + ($slText -join '; ') + '</div>')
        }
        [void]$sb.Append('<table><tr><th>' + (Enc $T.StlpecCiel) + '</th><th>' + (Enc $T.StlpecPort) + '</th><th>' + (Enc $T.StlpecVzorky) + '</th><th>' + (Enc $T.StlpecVyznam) + '</th></tr>')
        foreach ($c in $pg.Ciele.Values) {
            $c.VzorkyPocet = $c.Vzorky.Count
            $m = 0; foreach ($v in $c.Vzorky.Values) { if ($v -gt $m) { $m = $v } }
            $c.Naraz = $m
        }
        $cieleZ = $pg.Ciele.Values | Sort-Object @{ e = { $_.VzorkyPocet }; Descending = $true }, @{ e = { $_.Naraz }; Descending = $true }
        foreach ($c in $cieleZ) {
            $jeIP = ($c.Zdroj -eq 'ip')
            $vz = Get-VyznamDomeny -Domena $c.Ciel -JeIP $jeIP
            $badge = $T.TypBadge[$vz.Typ]
            if ($jeIP) { $cielHtml = '<span class="ip">' + (Enc $c.Ciel) + '</span>' }
            else {
                $cielHtml = (Enc $c.Ciel) + ' <span class="ip">(' + (Enc $c.IP) + ')</span>'
                if ($c.Zdroj -eq 'rev') { $cielHtml += '<span class="b rev">' + (Enc $T.ZdrojRev) + '</span>' }
            }
            $portHtml = Enc $c.Port
            if ($SlovnikPortov.ContainsKey([string]$c.Port)) {
                $pcls = if ([string]$c.Port -eq '80') { 'pn p80' } else { 'pn' }
                $portHtml += '<br><span class="' + $pcls + '">' + (Enc $SlovnikPortov[[string]$c.Port][$Jazyk]) + '</span>'
            }
            $castoHtml = (Enc ($T.VzorkyText -f $c.VzorkyPocet, $vzoriek))
            if ($c.Naraz -gt 1) { $castoHtml += '<br><span class="pn">' + (Enc ($T.NarazText -f $c.Naraz)) + '</span>' }
            [void]$sb.Append('<tr><td>' + $cielHtml + '</td><td>' + $portHtml + '</td><td>' + $castoHtml + '</td><td><span class="b ' + $vz.Typ + '">' + (Enc $badge) + '</span>' + (Enc $vz.Text) + '</td></tr>')
        }
        [void]$sb.Append('</table></div>')
    }
}

# päta
[void]$sb.Append('<footer><div class="big">' + (Enc $T.PataVeta) + '</div><div>' + (Enc $T.PataHranice) + '</div><div>' + (Enc $T.PataQuic) + '</div><div>' + (Enc $T.PataDlhsi) + '</div>')
if ($Mena) { [void]$sb.Append('<div>' + (Enc $T.PataRev) + '</div>') }
[void]$sb.Append('<div style="margin-top:10px">' + (Enc $T.PataPodpis) + '</div></footer>')
[void]$sb.Append('</div></body></html>')

# uloženie vedľa skriptu
$koren = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$subor = Join-Path $koren ('KONTRA_report_{0}.html' -f (Get-Date -Format 'yyyy-MM-dd_HHmm'))
[System.IO.File]::WriteAllText($subor, $sb.ToString(), [System.Text.Encoding]::UTF8)

Write-Host ''
Write-Host ('  ' + ($T.KonzolaReport -f $subor)) -ForegroundColor Cyan
Write-Host ('  ' + $T.KonzolaOtvaram) -ForegroundColor DarkGray
Start-Process $subor
Write-Host ('  ' + $T.KonzolaHotovo) -ForegroundColor Green
Write-Host ''
