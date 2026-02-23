# Lokalizacija (Locales)

Ovdje su tekstovi po jezicima. Jezik se bira u **Postavke → General → Jezik**.

## Jedna datoteka po jeziku (bez duplikata imena)

- **hr.json** – hrvatski  
- **en.json** – engleski  
- **de.json** – njemački  
- **fr.json** – francuski  
- **it.json** – talijanski  
- **es.json** – španjolski  

Sve datoteke su u mapi **Locales/** (nema podmapa), da Xcode ne bi pri buildanju prijavio „Multiple commands produce strings.json”.

## Uređivanje teksta

Svaka datoteka je običan JSON: par **ključ** → **vrijednost**. Ključevi su isti u svim jezicima; mijenjaj samo vrijednosti (tekst koji se prikazuje).

### Primjer (hr.json)

```json
{
  "wall": "Zid",
  "apple_farm": "Jabuka",
  "category_farm": "Farma",
  "soon": "Uskoro"
}
```

### Dodavanje novog teksta

1. Dodaj novi ključ u **sve** datoteke (hr.json, en.json, …), npr. `"menu_start": "Nova igra"`.
2. U kodu koristi: `LocalizedStrings.string(for: "menu_start", language: gameState.appLanguage)`.

### Ključevi donjeg izbornika

- `wall`, `apple_farm`, `pig_farm`, `hay_farm`, `cow_farm`, `sheep_farm`, `wheat_farm` – gumbi u izborniku  
- `category_castle`, `category_sword`, `category_mine`, `category_farm`, `category_food` – nazivi kategorija  
- `soon` – „Uskoro” za kategorije koje još nisu implementirane  
