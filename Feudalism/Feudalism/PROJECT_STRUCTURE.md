# Feudalism – struktura projekta

## Ulaz u aplikaciju
- **FeudalismApp.swift** – `@main`, SwiftUI WindowGroup, prebacuje MainMenu / MapEditor / ContentView
- **AppDelegate.swift** – fullscreen, crna pozadina pri pokretanju

## Prikaz mape (3D vizualizacija)
- **Game/GameView.swift** – NSViewRepresentable, SKView, 3D tilt, overlay stupova, zoom/pan callbacki
- **Game/GameScene.swift** – SpriteKit scena: teren, mreža, kamera, stupovi (callback u view koord.)
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
- **Core/Objects/** – GameObject, ObjectCatalog, ObjectCategory; Wall (zid + .obj/.mtl)
- **Core/AI/** – AILordProfile, AILordProfileStore, ComputerLordAI, GameSituationSnapshot
- **Core/Realms/** – Realm, RealmGroup

## Resursi
- **Assets.xcassets** – ikone (castle, sword, farm, food), AppIcon, AccentColor
- **Core/Objects/Wall/Wall/** – .obj i .mtl model zida

## Uklonjeno (nepotrebno)
- ~~ViewController.swift~~ – stari AppKit controller, učitavao GameScene.sks; aplikacija koristi SwiftUI + GameView/GameScene u kodu
- ~~Base.lproj/Main.storyboard~~ – referencirao ViewController; ulaz je FeudalismApp (SwiftUI)
