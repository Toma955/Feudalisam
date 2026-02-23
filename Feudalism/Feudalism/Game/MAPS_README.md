# Mape (.scn) – format i učitavanje

## Solo mod – generiraj pa učitaj, ili samo učitaj

Kad se igra pokrene u **solo modu**:

1. **Ako mapa postoji** → samo se učitava. Redoslijed: prvo level iz bundlea (`currentLevelName`, npr. `Level.scn`), pa ako ne nađe, spremljeni **SoloLevel.scn** u Application Support (Feudalism/SoloLevel.scn).
2. **Ako ne postoji** → generira se proceduralni teren, sprema se u **SoloLevel.scn**, pa se taj level učitava. Sljedeći put se učitava već spremljena mapa.

U **ne-solo** modu koristi se samo bundle level po `currentLevelName` ili proceduralni teren.

## Format

- **Level = .scn** (SceneKit scene). Vizualni layout mape; gameplay objekti (zidovi, zgrade) se **ne** stavljaju u .scn – spawnaju se iz `GameMap` / `Placement` u kodu.
- **Modeli** (pojedinačni objekti) mogu biti .dae, .usdz ili .scn; u levelu ih referenciraš ili ih kod učitava po potrebi.

## Što mora sadržavati Level.scn

1. **Node imena `terrain`**  
   Jedan čvor u hijerarhiji **mora** imati `name = "terrain"`. Na njega se radi hit test (klik na mapu → row/col).  
   Ako u .scn nema nodea "terrain", koristi se proceduralni ravninski teren kao fallback.

2. **Koordinatni sustav**  
   Preporuka: centar mape u (0, 0, 0), širina/visina **4000×4000** world jedinica, da odgovara `worldPositionAtCell` / `cellFromMapLocalPosition` (100×100 ćelija).

3. **Ostalo**  
   U .scn možeš dodati statičke objekte (drveće, kamenje, ceste). Kamera, svjetla i **placements** (zgrade, zidovi) dodaje view iz koda.

## Gdje staviti datoteke

- **Level.scn** (ili npr. **Maps/Level.scn**): u Xcodeu dodaj u projekt (Copy Bundle Resources ako treba).
- **GameState.currentLevelName**: ime bez ekstenzije, npr. `"Level"` ili `"Maps/Level"`. Ako je `nil`, koristi se samo proceduralni teren.

## Kako dodati novu mapu

1. U Xcodeu: File → New → File → SceneKit Scene. Spremi npr. kao `Level.scn` u grupu `Feudalism` ili `Game`.
2. U sceni označi glavni teren (plane ili mesh) i u Inspectoru postavi **Name** na `terrain`.
3. U kodu postavi `gameState.currentLevelName = "Level"` (ili putanja npr. `"Maps/Level"`) prije pokretanja igre ili u postavkama odabira mape.
