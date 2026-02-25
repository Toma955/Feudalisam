# Teksture terena (voda, vegetacija, zemlja, planina)

Ova mapa sadrži tilabilne slike za prikaz terena na mapi. Svaka ćelija mape koristi jednu sliku ovisno o `TerrainType`:

| Datoteka    | Tip terena | Opis                          |
|-------------|------------|-------------------------------|
| `grass.png` | Trava      | Zelena vegetacija / livada     |
| `water.png` | Voda       | Rijeke, jezera                |
| `forest.png`| Šuma       | Tamno zelena šuma             |
| `mountain.png` | Planina | Siva / kamenita podloga       |

**Preporuka:** 64×64 ili 128×128 px, tilabilne (repeat na rubovima). Ako datoteka nedostaje, koristi se proceduralna boja (zelena/plava/siva).

**Placeholder slike (opcionalno):** Možeš dodati jednostavne PNG datoteke npr. Pythonom:
`python3 -c "from PIL import Image; [(Image.new('RGB',(64,64),(int(r*255),int(g*255),int(b*255))).save(n+'.png')) for n,(r,g,b) in [('grass',(0.45,0.68,0.32)),('water',(0.25,0.45,0.75)),('forest',(0.22,0.42,0.22)),('mountain',(0.5,0.48,0.45))]]"`
(zahtijeva `pip install Pillow`). Inače aplikacija koristi iste boje generirane u kodu.
