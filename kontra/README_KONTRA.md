# KONTRA · Who is watching? · Veľký brat pod lupou

FYI nástroj AIForce · BASIC · verzia 5 · PowerShell 5.1 (Windows 11) · report v slovenčine alebo češtine

KONTRA iba číta. Nič nemení, nič nevypína, nič neinštaluje, nepotrebuje admin práva.

## Spustenie

1. Otvor PowerShell v zložke `C:\Nastroje\KONTRA` (Shift + pravý klik v zložke › *Otvoriť okno PowerShellu tu*).
2. Spusti:

```powershell
powershell -ExecutionPolicy Bypass -File .\kontra.ps1 -Mena
```

3. KONTRA sa na začiatku opýta na jazyk reportu: `1` = slovensky, `2` = česky, Enter = slovensky.

Beží 60 sekúnd, potom sa v prehliadači otvorí report `KONTRA_report_<dátum>.html` uložený vedľa skriptu. Report je celý v zvolenom jazyku (nie je to preklad hotového reportu).

## Prepínače

| Prepínač | Čo robí |
|---|---|
| *(bez prepínača)* | Minútový sken. Nič neposiela, mená domén iba z lokálnej DNS pamäte. Jazyk sa vyberie na začiatku. |
| `-Jazyk sk` / `-Jazyk cs` | Jazyk reportu bez otázky (`cz` sa berie ako `cs`). |
| `-Mena` | Pre IP adresy bez mena urobí spätný DNS dopyt. Jediný prípad, keď KONTRA sama niečo pošle na internet. Odporúčané, pomenuje väčšinu adries. |
| `-Sekundy 600` | Dlhší sken (tu 10 minút). Pre skutočný obraz: telemetria posiela v dávkach a minútová vzorka ju minie. |

## Čo report ukazuje

- **Verdikt:** koľko nastavení súkromia posiela údaje · koľko programov komunikovalo · koľko cieľov je známa telemetria alebo analytika.
- **Časť A:** 7 nastavení súkromia Windows so semaforom 🟢 🟠 ⚪ a návodom, kde ich nájsť.
- **Časť B:** program → kam → ako často, s laickým vysvetlením zo slovníka domén, programov, služieb, portov a IP rozsahov.
- **Päta:** čo KONTRA nevidí (obsah prenosu, QUIC/UDP prevádzka prehliadačov).

## Hranice (pravdivo)

- Vidí **kto a kam**, nie **čo** (prenos je šifrovaný).
- Číta iba TCP. Prehliadače cez HTTP/3 (QUIC) nevidí.
- Na Windows Home/Pro sa telemetria nedá vypnúť úplne, minimum je úroveň *Required*.
- Recall: ak nie je vypnutý politikou, ukáže ⚪ a pošle ťa do Nastavení.

## Keď ťa niečo vyľaká

Pošli celý report svojej AI (ChatGPT, Claude, Gemini alebo lokálnemu modelu) a opýtaj sa: *„Čo z toho je bežné a čo by som mal riešiť?“* Report obsahuje mená tvojich programov a internetových adries, takže si ho pred odoslaním prečítaj.

## Zložka

```
C:\Nastroje\KONTRA\
   kontra.ps1
   ZADANIE_KONTRA.md     ← zadanie (SK), podľa ktorého nástroj vznikol (zverejňuje sa)
   ZADANIE_KONTRA_cz.md  ← to isté po česky
   README_KONTRA.md      ← tento súbor
   README_KONTRA_cz.md   ← po česky
   KONTRA_report_*.html  ← výstupy, môžeš mazať
```
