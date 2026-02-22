# Wall – 3D model zida (igra je 3D)

U podmapi **Wall/** nalaze se datoteke skinute s interneta (Meshy AI Stone Wall):

- `Meshy_AI_Stone_Wall_0221071847_texture.obj` – mesh
- `Meshy_AI_Stone_Wall_0221071847_texture.mtl` – materijal (referencira .png)
- `texture.png` – tekstura (u istoj mapi Wall/; .mtl je referencira).

**Za korištenje u igri (3D):** U Xcodeu dodaj cijelu mapu **Wall** (s .obj, .mtl i .png) u target **Feudalism** (File → Add Files, označi "Copy items if needed" i target Feudalism). Tada će bundle sadržavati `Wall/` i igra može učitati model preko `Wall.modelURL()` odnosno `Wall.loadSceneKitNode()`.
