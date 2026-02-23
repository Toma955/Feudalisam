# Tržnica (Market) – 3D objekt

U ovoj mapi **Market/** možeš spremiti datoteke za objekt Tržnica:

- **.obj** – 3D mesh (npr. `market.obj` ili `trznica.obj`)
- **.mtl** – materijal (referencira teksturu)
- **.png** (ili druge formate) – teksture

Nakon što dodaš datoteke, u Xcodeu ih uključi u target **Feudalism** (Add Files → označi Copy items if needed i target Feudalism). Za učitavanje u igri možeš koristiti isti princip kao za Wall (ObjectCatalog, BuildCosts, placement s `object_market`).
