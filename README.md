# 🐾 Smart Cat Feeder

Kompletan IoT sistem za automatsko i ručno hranjenje mačaka, sa ESP32 hardverom, ASP.NET Core backend-om, SQL Server bazom, Flutter mobilnom aplikacijom i Docker kontejnerizacijom.

## 📋 Opis projekta

Smart Cat Feeder je full-stack IoT projekat koji omogućava:

- 🍽️ **Doziranje hrane** — ručno preko app-a ili automatski po rasporedu
- 💧 **Praćenje i dopunjavanje vode** (u razvoju — pumpa + senzor nivoa)
- 🐱 **Podršku za više mačaka** — svaka sa svojom istorijom hranjenja i rasporedom
- 📊 **Praćenje senzora** — nivo hrane, nivo vode, temperatura, vlažnost
- 📅 **Raspored hranjenja** — po danima u sedmici i tačnom vremenu, čuva se i radi preko RTC-a bez interneta
- 📱 **Mobilnu aplikaciju** — Android/iOS/Web, sa podešavanjem adrese servera direktno iz app-a
- 🐳 **Docker** — baza (i backend) rade u kontejnerima na lokalnom računaru, podaci ostaju lokalni

## 🏗️ Arhitektura

```
┌─────────────┐        ┌────────────────────┐        ┌───────────────┐
│    ESP32    │──HTTP─▶│   ASP.NET Core      │◀──────▶│  SQL Server   │
│ + Senzori   │        │   Backend API       │ EF Core │  (Docker)     │
│ + Servo     │◀───────│   (Docker host)     │        └───────────────┘
│ + Pumpa     │        └────────────────────┘
└─────────────┘                  ▲
                                  │ REST API (JSON, CORS)
                                  ▼
                         ┌────────────────────┐
                         │   Flutter App       │
                         │   Android / iOS /   │
                         │   Web (Safari, itd.) │
                         └────────────────────┘
```

## 🚀 Značajke

### ESP32 Firmware *(u razvoju)*
- WiFi povezivanje
- Servo motor za doziranje hrane (MG996R/SG90)
- Load cell + HX711 — precizno mjerenje težine hrane
- HC-SR04 — nivo hrane u levku
- DHT22 — temperatura i vlažnost
- DS3231 RTC — raspored radi i bez interneta
- RC522 RFID — prepoznavanje koje mačke jedu
- Mini pumpa + MOSFET driver — automatsko dopunjavanje vode
- Slanje očitavanja na backend (`POST /api/sensorreadings`)

### Backend (ASP.NET Core Web API, .NET 10)
- REST API sa punim CRUD-om za mačke, rasporede, hranjenja i senzorska očitavanja
- Entity Framework Core + SQL Server, konekcija kroz Dependency Injection
- Validacija ulaznih podataka sa jasnim porukama grešaka
- Globalno rukovanje izuzecima (čitljiv JSON odgovor umjesto generičkog 500)
- CORS podrška (za Flutter Web pristup)
- OpenAPI dokument dostupan u Development modu

### Mobilna app (Flutter)
- Dashboard sa uživo statusom (nivo hrane, nivo vode, temperatura, vlažnost)
- Ručno hranjenje sa izborom mačke, animiranom reakcijom mačke i porcijom
- Dodavanje/uređivanje/brisanje mačaka
- Puni CRUD za raspored hranjenja (dani u sedmici, vrijeme, količina)
- Historija hranjenja i pregled rasporeda
- Podešavanja — adresa backend servera se mijenja direktno iz app-a, uz test konekcije, bez diranja koda

### Baza podataka
- SQL Server 2022, pokreće se u Docker kontejneru
- Trajno čuvanje podataka preko Docker volume-a (`sql_data`)

## 📦 Instalacija

### Preduslovi
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- [Flutter SDK](https://flutter.dev) + Android Studio (za Android build)
- SQL Server Management Studio (SSMS) — opciono, za ručni uvid u bazu
- PlatformIO ili Arduino IDE — za ESP32 firmware (kasnija faza)

### 1. Kloniranje repozitorija

```bash
git clone https://github.com/asadevejza/CatFeeder.git
cd CatFeeder
```

### 2. Konfiguracija tajni (.env i appsettings.json)

Lozinke se ne čuvaju u git-u — svako ko klonira repo pravi svoje lokalne kopije:

```bash
cp .env.example .env
cp CatFeeder.Api/appsettings.json.example CatFeeder.Api/appsettings.json
```

Otvori oba fajla i unesi svoju lozinku (mora biti **ista** u oba — `.env` je za Docker/SQL Server, `appsettings.json` je ono što backend koristi da se poveže na tu istu bazu).

### 3. Pokretanje baze (Docker)

U root folderu projekta, gdje je `docker-compose.yml`:

```bash
docker compose up -d
```

Ovo diže SQL Server na `localhost:14330` (mapiran zbog izbjegavanja sukoba sa eventualnim native SQL Server instalacijama na portu 1433).

### 4. Pokretanje backend-a

```bash
cd CatFeeder.Api
dotnet ef database update --project ../CatFeeder.Data
dotnet run
```

Backend će slušati na `http://0.0.0.0:5103` — dostupan i lokalno i sa drugih uređaja na istoj mreži.

### 5. Pokretanje mobilne app

```bash
cd Mobile
flutter pub get
flutter run
```

U app-u, na ekranu **Podešavanja**, unesi adresu backend servera:
- Android Emulator: `http://10.0.2.2:5103/api`
- Pravi telefon (ista WiFi mreža): `http://[LAN IP računara]:5103/api`
- Flutter Web (iPhone Safari i sl.): `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080`, pa isti LAN IP princip

## 🔧 Hardware setup *(sljedeća faza)*

Kompletna lista komponenti (elektronika, napajanje, mehanika, alat, i sistem za vodu) nalazi se u `docs/lista_za_kupovinu.docx`. Sažetak ključnih dijelova:

- ESP32 Dev Board
- Servo motor (doziranje hrane)
- Load cell + HX711 (mjerenje težine)
- HC-SR04 × 2 (nivo hrane i nivo vode)
- DHT22 (temperatura/vlažnost)
- DS3231 RTC modul
- RC522 RFID modul
- Mini pumpa za vodu + MOSFET/relej driver

## 📖 API dokumentacija

U Development modu, OpenAPI dokument je dostupan na:
```
http://localhost:5103/openapi/v1.json
```

Glavni endpointi:

| Metoda | Ruta | Opis |
|---|---|---|
| GET/POST/PUT/DELETE | `/api/cats` | Upravljanje mačkama |
| GET/POST | `/api/feedinglogs` | Historija hranjenja |
| GET/POST/PUT/DELETE | `/api/feedingschedules` | Rasporedi hranjenja |
| GET/POST | `/api/sensorreadings` | Očitavanja senzora (hrana, voda, temp, vlažnost) |

## 🗺️ Status projekta

- [x] Backend (ASP.NET Core + SQL Server + Docker)
- [x] Mobilna aplikacija (Flutter — Android, iOS/Web preko browsera)
- [x] Podrška za više mačaka
- [x] Raspored hranjenja (puni CRUD)
- [x] Praćenje nivoa hrane i vode (softverski dio)
- [ ] ESP32 firmware
- [ ] Fizička montaža hranilice
- [ ] Automatsko dopunjavanje vode (pumpa)
- [ ] Udaljeni pristup van kućne mreže (Tailscale)

## 📝 Licenca

MIT License

## 👤 Autor

Tvoje ime ovdje
