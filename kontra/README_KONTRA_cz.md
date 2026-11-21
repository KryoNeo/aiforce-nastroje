# KONTRA · Who is watching? · Velký bratr pod lupou

FYI nástroj AIForce · BASIC · verze 5 · PowerShell 5.1 (Windows 11) · report ve slovenštině nebo češtině

KONTRA jen čte. Nic nemění, nic nevypíná, nic neinstaluje, nepotřebuje práva správce.

## Spuštění

1. Otevři PowerShell ve složce `C:\Nastroje\KONTRA` (Shift + pravé tlačítko ve složce › *Otevřít okno PowerShellu zde*).
2. Spusť:

```powershell
powershell -ExecutionPolicy Bypass -File .\kontra.ps1 -Mena
```

3. KONTRA se na začátku zeptá na jazyk reportu: `1` = slovensky, `2` = česky, Enter = slovensky.

Běží 60 sekund, poté se v prohlížeči otevře report `KONTRA_report_<datum>.html` uložený vedle skriptu. Report je celý ve zvoleném jazyce (není to překlad hotového reportu). Chceš-li česky bez otázky, přidej `-Jazyk cs`.

## Přepínače

| Přepínač | Co dělá |
|---|---|
| *(bez přepínače)* | Minutový sken. Nic neodesílá, jména domén jen z lokální DNS paměti. Jazyk se vybere na začátku. |
| `-Jazyk sk` / `-Jazyk cs` | Jazyk reportu bez otázky (`cz` se bere jako `cs`). |
| `-Mena` (česky „jména“) | Pro IP adresy bez jména provede zpětný DNS dotaz. Jediný případ, kdy KONTRA sama něco odešle na internet. Doporučeno, pojmenuje většinu adres. |
| `-Sekundy 600` | Delší sken (zde 10 minut). Pro skutečný obraz: telemetrie odesílá v dávkách a minutový vzorek ji mine. |

## Co report ukazuje

- **Verdikt:** kolik nastavení soukromí odesílá údaje · kolik programů komunikovalo · kolik cílů je známá telemetrie nebo analytika.
- **Část A:** 7 nastavení soukromí Windows se semaforem 🟢 🟠 ⚪ a návodem, kde je najdeš.
- **Část B:** program → kam → jak často, s laickým vysvětlením ze slovníku domén, programů, služeb, portů a IP rozsahů.
- **Pata:** co KONTRA nevidí (obsah přenosu, QUIC/UDP provoz prohlížečů).

## Hranice (pravdivě)

- Vidí **kdo a kam**, ne **co** (přenos je šifrovaný).
- Čte jen TCP. Prohlížeče přes HTTP/3 (QUIC) nevidí.
- Na Windows Home/Pro nelze telemetrii vypnout úplně, minimum je úroveň *Required*.
- Recall: pokud není vypnutý zásadou, ukáže ⚪ a pošle tě do Nastavení.

## Když tě něco vyděsí

Pošli celý report své AI (ChatGPT, Claude, Gemini nebo lokálnímu modelu) a zeptej se: *„Co z toho je běžné a co bych měl řešit?“* Report obsahuje jména tvých programů a internetových adres, takže si ho před odesláním přečti.

## Složka

```
C:\Nastroje\KONTRA\
   kontra.ps1
   ZADANIE_KONTRA.md     ← zadání (SK), podle kterého nástroj vznikl (zveřejňuje se)
   ZADANIE_KONTRA_cz.md  ← totéž česky
   README_KONTRA.md      ← slovensky
   README_KONTRA_cz.md   ← tento soubor
   KONTRA_report_*.html  ← výstupy, můžeš mazat
```
