# Feudalism – struktura projekta

## Ulaz u aplikaciju
- **FeudalismApp.swift** – `@main`, SwiftUI WindowGroup, prebacuje MainMenu / MapEditor / ContentView
- **AppDelegate.swift** – fullscreen, crna pozadina pri pokretanju

## Prikaz mape (3D vizualizacija)
- **Game/SceneKitMapView.swift** – SceneKit prikaz mape (teren, grid, placements, kamera). Ako je u GameState postavljen `currentLevelName`, učitava se **Level.scn**; inače proceduralni teren.
- **Game/SceneKitLevelLoader.swift** – učitavanje .scn levela (vizualni layout). Level = .scn; gameplay objekti se spawnaju iz GameMap u kodu.
- **Game/MAPS_README.md** – format mape (.scn), obavezan node `terrain`, koordinatni sustav 4000×4000.
- **Game/GameView.swift** – NSViewRepresentable, SKView (legacy/alternativa)
- **Game/GameScene.swift** – SpriteKit scena (legacy)
- **Core/MapCameraSettings.swift** – zoom, tilt, panOffset, mapRotation, panSpeed

## Glavni ekrani (SwiftUI)
- **ContentView.swift** – glavni ekran igre (mapa + HUD, grid toggle, zoom slider)
- **Views/MainMenuView.swift** – glavni izbornik (Solo, Nova igra, Editor, Postavke)
- **Views/MapEditorView.swift** – editor mape (GameView + alatna traka)
- **Views/CompassCubeView.swift** – kocka za rotaciju i pan
- **Views/PostavkeView.swift** – postavke (placeholder)
- **Views/GameSetupView.swift** – postavke nove igre
- **Views/FireBackgroundView.swift** – pozadina glavnog izbornika

## Jezgra (Core)
- **Core/GameState.swift** – globalno stanje (mapCameraSettings, isMapEditorMode, gameMap, …)
- **Core/Map/** – GameMap, Placement, MapCoordinate, MapCell, MapSizePreset, SpatialSize
- **Core/Objects/** – GameObject, ObjectCatalog, ObjectCategory; Castle (Castle.swift, Wall/, Market/ s .obj/.mtl)
- **Core/AI/** – AILordProfile, AILordProfileStore, ComputerLordAI, GameSituationSnapshot
- **Core/Realms/** – Realm, RealmGroup

## Važno – ne dirati
- **Core/Objects/Castle/Wall/** – **NIKAD NE DIRATI.** Wall.swift, Wall.obj, Wall.mtl, Wall_texture.png ostaju netaknuti. Ni jedan commit ne smije mijenjati Wall.

## Trenutni fokus (samo Stepenice)
- **Samo:** objekt **Stepenice** (object_stepenice) koji se aktivira kad se u Dvoru klikne **Stepenice** (castle_steps).
- Gumb Stepenice postavlja `selectedPlacementObjectId = Stepenice.objectId` (ContentView). Zid (Wall) se aktivira isključivo gumbom Zid.
- Ne dirati Wall; sve izmjene samo za Stepenice ili opću logiku (ghost, placement).

## Resursi
- **Assets.xcassets** – ikone (castle, sword, farm, food), AppIcon, AccentColor
- **Core/Objects/Castle/Wall/** – Wall.obj, Wall.mtl, Wall_texture.png (model zida)
- **Core/Objects/Castle/Market/** – Market.obj, Market.mtl, Market_texture.png (model tržnice)

## Uklonjeno (nepotrebno)
- ~~ViewController.swift~~ – stari AppKit controller, učitavao GameScene.sks; aplikacija koristi SwiftUI + GameView/GameScene u kodu
- ~~Base.lproj/Main.storyboard~~ – referencirao ViewController; ulaz je FeudalismApp (SwiftUI)
