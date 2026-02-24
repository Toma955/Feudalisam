# Prijedlozi optimizacije i OOP – Feudalism

Dubinska analiza koda s prijedlozima koji **ne mijenjaju krajnji rezultat** (samo čišćenje, brzina, OOP, održivost).

---

## 1. State management (GameState, re-renderi)

### 1.1 Redundantni `objectWillChange` / `placementsVersion`
- **Lokacija:** `Core/GameState.swift` – `placeSelectedObjectAt` (303–334), `removePlacement` (338–344).
- **Problem:** Nakon `placementsVersion += 1` (koji je `@Published`) poziva se i `objectWillChange.send()` – duplo obavještavanje.
- **Prijedlog:** Ukloniti eksplicitni `objectWillChange.send()` tamo gdje se mijenja samo `@Published` property. Zadržati samo `placementsVersion += 1` (ili samo `objectWillChange` ako želiš manje re-rendera, ali konzistentno).

### 1.2 GameMap + GameState dupla notifikacija
- **Lokacija:** `Core/Map/GameMap.swift` (place, removePlacement, replacePlacements) i GameState koji poziva te metode.
- **Problem:** GameMap šalje `objectWillChange.send()`, a GameState također ažurira placementsVersion – viewovi primaju dvostruku invalidaciju.
- **Prijedlog:** Odlučiti jedan izvor istine: ili GameMap ne šalje objectWillChange (samo GameState), ili GameState ne šalje kada delegira u GameMap. Time se smanjuje broj re-evaluacija body-ja bez promjene ponašanja.

### 1.3 Ograničiti re-render na HUD kad se mijenja samo kamera
- **Lokacija:** `ContentView.swift` – gameHUD koristi `gameState.mapCameraSettings` preko Bindinga.
- **Problem:** Svaka promjena pan/zoom/rotacije invalidira cijeli ContentView body (uključujući veliki HUD i bottom bar).
- **Prijedlog:** Izvući CompassCubeView i ZoomPhaseView u zasebni view koji prima samo `MapCameraSettings` (npr. `@ObservedObject` za mali wrapper koji drži samo camera settings), ili koristiti `equatable()` na tom dijelu da SwiftUI ne re-rendera ostatak kad se mijenja samo kamera. Rezultat na ekranu ostaje isti, manje CPU-a.

---

## 2. SceneKit – performanse (bez promjene izgleda)

### 2.1 Grid: ne graditi 200 nodova na svaki zoom
- **Lokacija:** `Game/SceneKitMapView.swift` – `refreshGrid` (481–516), poziv iz `updateNSView` kad se zoom mijenja.
- **Problem:** Na svaku promjenu zooma uklanjaju se svi child nodovi i kreira ~200 novih SCNBox + SCNNode. To može trznuti.
- **Prijedlog:** (A) Ažurirati samo **debljinu linija** (scale ili geometry) postojećih nodova umjesto brisanja i ponovnog stvaranja; ili (B) držati pool nodova i samo mijenjati `lineW`/`lineH` i visibility. Izgled gridа ostaje isti, manje alokacija.

### 2.2 Throttle / coalesce onMouseMove
- **Lokacija:** `Game/SceneKitMapView.swift` – `onMouseMove` (519–538), poziva hitTest + cellFromMapLocalPosition + ghost update na svaki pomak miša.
- **Prijedlog:** Throttlati na npr. 60 fps (ili 30 ms): zadržati zadnju poziciju i ažurirati ghost u timeru ili u Coordinatoru `renderer(_:updateAtTime:)` s throttle-om. Klikovi i vizualni rezultat ostaju isti, manje CPU na move.

### 2.3 Cache tekstura u reapplyTexture
- **Lokacija:** `Game/SceneKitMapView.swift` – `refreshPlacements` (917–958); `SceneKitPlacementRegistry.reapplyTexture(objectId:to:bundle:)` za svaki klon.
- **Problem:** Za svaki placement (npr. zid od 10 ćelija) poziva se reapplyTexture 10 puta; unutra se učitava tekstura (npr. Wall.loadTextureImage) – ponovno za svaki poziv.
- **Prijedlog:** Cacheirati učitane teksture po `objectId` (npr. u SceneKitPlacementRegistry ili u memoriji viewa): prvi poziv učitava i spremi, sljedeći koriste cache. Rezultat na ekranu isti, manje I/O i dekodiranja.

### 2.4 Level generiranje izvan main threada
- **Lokacija:** `Game/SceneKitMapView.swift` – `makeNSView` (447–461); kada nema cachea, `generateAndSaveSoloLevel` se zove **sinkronizirano** na main threadu (briše file, piše PNG, piše .scn).
- **Prijedlog:** Generiranje i spremanje levela premjestiti u `Task { }`: u makeNSView prikazati loading overlay, u Task pozvati generateAndSaveSoloLevel, na kraju na MainActor dodati level u scenu i sakriti overlay. Ponašanje isto, UI ne blokira.

---

## 3. OOP i smanjenje duplikacije (isti rezultat)

### 3.1 Jedan “Expanded bar” view umjesto 7 sličnih
- **Lokacija:** `Views/BottomBar/` – CastleButtonExpandedView, FoodButtonExpandedView, FarmButtonExpandedView, HouseButtonExpandedView, MineButtonExpandedView, SwordButtonExpandedView, ToolsButtonExpandedView.
- **Problem:** Sličan layout (VStack/HStack, gumb 48pt, label ispod), samo podaci (ikone, LocalizedStrings ključevi, akcije) se razlikuju.
- **Prijedlog:** Uvesti jedan generički view npr. `CategoryExpandedView` s konfiguracijom: `[(iconName: String, systemFallback: String, labelKey: String, action: () -> Void)]`. Svaka kategorija preda svoj niz. Izgled i ponašanje ostaju isto, manje koda za održavanje.

### 3.2 Protocol za placeable objekte (Wall, Market, Windmill, …)
- **Lokacija:** `Game/SceneKitPlacementRegistry.swift` – switch po `objectId` u `loadSceneKitNode` i `reapplyTexture`; svaki tip (Wall, Market, …) ima istu strukturu: modelURL, texture dirs, loadTextureImage, reapplyTexture.
- **Problem:** Dodavanje novog tipa zahtijeva izmjenu u nekoliko mjesta (placeableObjectIds, oba switcha).
- **Prijedlog:** Uvesti protocol npr. `PlaceableSceneKitObject` s `objectId`, `modelURL`, `loadTextureImage`, `reapplyTexture`. Svaki enum (Wall, Market, …) konformira; registry gradi listu iz kataloga i koristi protocol. Krajnji rezultat isti, lakše dodavanje novih objekata.

### 3.3 Centralizirati učitavanje ikona (loadBarIcon)
- **Lokacija:** `Views/BottomBar/BarIconView.swift` (loadBarIcon), ContentView (loadResourceIcon → loadBarIcon), ZoomPhaseView i ostali koji oponašaju istu logiku.
- **Prijedlog:** Jedan servis ili singleton (npr. `BarIconCache`) s metodom `image(named:fallback:)` i jednostavnim memory cacheom (po imenu). Svi viewovi koriste taj isti pristup. Izgled ikona isti, manje duplikata i mogućnost cacheiranja.

---

## 4. Duži metode – razdvojiti bez promjene ponašanja

### 4.1 makeNSView
- **Lokacija:** `Game/SceneKitMapView.swift` (428–548).
- **Prijedlog:** Izvući u private metode: `setupSceneAndTerrain`, `setupCameraAndLights`, `setupPlacementTemplatesAndGhosts`, `attachInputHandlers`. makeNSView samo poziva te funkcije. Ponašanje identično, čitljivost bolja.

### 4.2 refreshPlacements
- **Lokacija:** `Game/SceneKitMapView.swift` (917–958).
- **Prijedlog:** Jedna pomoćna funkcija npr. `addPlacementNode(for:at:to:templates:)` koja radi clone + position + reapplyTexture za jedan placement; refreshPlacements ostaje jedna petlja koja ju poziva. Isti rezultat, jasnija struktura.

### 4.3 GameState
- **Lokacija:** `Core/GameState.swift` – jedan veliki objekt za sve (menu, editor, resursi, placement, postavke, persistence).
- **Prijedlog:** Logički grupirati u extensione (npr. `GameState+Placement`, `GameState+MapEditor`, `GameState+Settings`) ili u pomoćne objekte koje GameState drži (npr. `PlacementState`, `MapEditorState`) – bez mijenjanja public API-ja i ponašanja. Samo organizacija koda.

---

## 5. Konstante i “magic numbers”

- **Lokacija:** Razbacano kroz SceneKitMapView (100, 4000, 2800, 0.18, 140, 32), ContentView (830, 620, 56, 520, 1100), MapCameraSettings (20°, 5°, 28, 2/8/14).
- **Prijedlog:** Grupirati u `enum Constants` ili `struct MapConstants` / `struct HUDConstants` s static let. Zamijeniti literale referencama. Ponašanje isto, lakše tuniranje i čitljivost.

---

## 6. Map dimenzije (potencijalni bug – samo napomena)

- **Lokacija:** `Game/SceneKitMapView.swift` – na vrhu `mapRows = 100`, `mapCols = 100`; `Core/Map` i GameState podržavaju 200×200, 1000×1000 (MapSizePreset).
- **Problem:** `cellFromMapLocalPosition`, `worldPositionAtCell`, `refreshGrid` koriste fiksno 100×100. Ako je gameMap 200×200, koordinate i grid ne odgovaraju.
- **Prijedlog:** Ako je namjera da mapa uvijek bude 100×100 u SceneKit viewu, dokumentirati to; inače koristiti `gameState.gameMap.rows/cols` u SceneKitMapView umjesto konstanti 100 (što bi bila promjena ponašanja – samo za napomenu ako planiraš veće mape).

---

## 7. Ostalo (niske prioritete)

- **Timer u ContentView:** `Timer.publish(every: 1, ...)` – ok za godišnja doba; ako želiš manje poziva, možeš povećati interval na 2 s ili ažurirati samo kad se godina/doba stvarno promijeni (isti prikaz).
- **printIconDiagnostics / imageWithTransparentWhiteBackground:** Ako se ne koriste u produkciji, možeš ih ukloniti ili zaštićivati s `#if DEBUG` – bez utjecaja na ponašanje.
- **Cursor u SceneKitMapNSView:** resetCursorRects ne postavlja mač/buzdovan; ako želiš konzistentno, dopuniti cursor logiku bez promjene gameplaya.

---

## Sažetak prioriteta

| Prioritet | Što | Utjecaj na rezultat |
|-----------|-----|----------------------|
| Visok    | Throttle onMouseMove, cache za reapplyTexture, grid bez full rebuild | Nema – brže |
| Visok    | Level generiranje u Task (ne na main) | Nema – UI ne blokira |
| Srednji  | Ukloniti redundantni objectWillChange | Nema – manje re-rendera |
| Srednji  | CategoryExpandedView (jedan view za sve kategorije) | Nema – manje koda |
| Srednji  | Protocol za PlaceableSceneKitObject | Nema – lakše proširenje |
| Nizak    | Konstante u enum/struct, podjela makeNSView/refreshPlacements | Nema – čitljivost |

Sve gore navedeno može se uvesti postupno; preporuka je prvo throttle + texture cache + async level generiranje, zatim OOP/refactor po želji.
