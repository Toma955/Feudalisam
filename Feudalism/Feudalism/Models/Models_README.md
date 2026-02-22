# 3D modeli za objekte na karti

Ovdje stavi 3D modele koje igra učitava za objekte (npr. zid).

## Wall (Zid)

- **Datoteka:** `Wall.obj` ili `Wall.usdz`
- Ime bez ekstenzije u kodu: **Wall** (`Wall.modelAssetName`)
- Format:
  - **.obj** – SceneKit/Metal ga može učitati
  - **.usdz** – Apple format (RealityKit/SceneKit), preporučeno za M‑čipove

**Važno:** U Xcodeu dodaj datoteku u target **Feudalism** (Copy items if needed) da bude u bundleu.
