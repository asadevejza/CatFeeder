# 🐾 Smart Cat Feeder

> **Pametna IoT hranilica za mačke sa AI funkcionalnostima**

Smart Cat Feeder je full-stack IoT projekat koji objedinjuje **ESP32 mikrokontroler**, **ASP.NET Core Web API**, **Flutter mobilnu aplikaciju**, **SQL Server bazu podataka**, **Docker** i **vještačku inteligenciju (AI)** u jedinstven sistem za nadzor i upravljanje hranjenjem kućnih ljubimaca.

Sistem omogućava praćenje stanja hranilice u realnom vremenu, upravljanje rasporedima hranjenja, automatsko i ručno hranjenje, analizu podataka te korištenje AI tehnologija za prepoznavanje mačke, pametne preporuke i razgovor sa AI asistentom.

---

# ✨ Glavne funkcionalnosti

## 📱 Mobilna aplikacija

Flutter aplikacija omogućava:

- 📊 Dashboard sa pregledom stanja hranilice
- 🐱 Upravljanje mačkama (CRUD)
- 🍽️ Ručno hranjenje
- 📅 Upravljanje rasporedima hranjenja
- 📖 Historiju hranjenja
- 🌡️ Prikaz temperature i vlažnosti
- 🥣 Prikaz nivoa hrane
- 💧 Prikaz nivoa vode
- ⚙️ Podešavanje adrese backend servera
- ✅ Test konekcije sa serverom
- 🔔 Lokalna obavještenja
- 🤖 AI chat asistenta
- 🐱 AI prepoznavanje mačke sa fotografije
- 📊 AI analizu navika hranjenja

Podržane platforme:

- Android
- iOS
- Flutter Web

---

## 🌐 Backend

Backend je razvijen koristeći **ASP.NET Core (.NET 10)**.

Sadrži:

- REST API
- Clean/Layered Architecture
- Entity Framework Core
- SQL Server
- Dependency Injection
- Global Exception Handling
- Validaciju zahtjeva
- OpenAPI (Swagger)
- CORS podršku
- JWT autentifikaciju
- X-Api-Key zaštitu

---

## 🤖 AI funkcionalnosti

### 🐱 AI prepoznavanje mačke

Backend koristi **ONNX Runtime** i **MobileNetV2** model za prepoznavanje mačke na fotografiji.

Nakon detekcije sistem:

- prepoznaje prisustvo mačke
- bilježi rezultat u bazu
- prikazuje rezultat korisniku
- šalje lokalnu notifikaciju

---

### 🍽️ AI automatsko hranjenje

Kada AI uspješno prepozna mačku, sistem može automatski evidentirati hranjenje koristeći planiranu porciju iz rasporeda.

---

### 💬 AI Chat Asistent

Mobilna aplikacija omogućava razgovor sa AI asistentom koristeći **Groq API**.

Korisnik može postavljati pitanja o:

- ishrani
- zdravlju
- ponašanju
- preporučenoj količini hrane
- općoj brizi o mački

---

### 📊 AI analiza

Sistem analizira:

- prosječnu dnevnu porciju hrane
- odstupanja u hranjenju
- trend tjelesne težine
- preporučenu količinu hrane (RER formula)
- anomalije u navikama hranjenja

---

### 🔔 Pametna upozorenja

Ako mačka nije hranjena određeni vremenski period, korisnik automatski dobija lokalnu notifikaciju.

---

# ⚡ ESP32 Hardver

ESP32 predstavlja centralni dio sistema.

Planirane/implementirane komponente:

- ESP32 Dev Board
- Servo motor
- HX711 + Load Cell
- HC-SR04 (hrana)
- HC-SR04 (voda)
- DHT22
- DS3231 RTC
- RC522 RFID
- Pumpa za vodu
- WiFi komunikacija

ESP32 periodično šalje senzorska očitanja backend-u i izvršava komande za hranjenje.

---

# 🗄️ Baza podataka

Za skladištenje podataka koristi se SQL Server.

Čuvaju se:

- mačke
- rasporedi hranjenja
- historija hranjenja
- senzorska očitanja
- AI detekcije
- evidencija težine

Baza koristi EF Core Migrations i Docker Volume za trajno čuvanje podataka.

---

# 🐳 Docker

Docker omogućava jednostavno pokretanje kompletnog sistema.

Servisi:

- SQL Server
- Backend
- Docker Volume za bazu

---

# 📂 Struktura projekta

```text
CatFeeder
│
├── .github/
│
├── backend/
│   ├── src/
│   ├── tests/
│   └── CatFeeder.sln
│
├── frontend/
│   └── mobile/
│
├── database/
│
├── docker/
│
├── docs/
│
├── scripts/
│
├── README.md
└── LICENSE
```

---

# 🛠️ Korištene tehnologije

## Backend

- ASP.NET Core 10
- Entity Framework Core
- SQL Server
- Docker

## Frontend

- Flutter
- Dart

## AI

- ONNX Runtime
- MobileNetV2
- Groq API

## Hardver

- ESP32
- HX711
- HC-SR04
- DHT22
- DS3231 RTC
- RC522 RFID
- Servo Motor
- Pumpa za vodu

---

# 🚀 Pokretanje projekta

## Potrebni alati

- .NET 10 SDK
- Flutter SDK
- Docker Desktop

---

## Kloniranje repozitorija

```bash
git clone https://github.com/asadevejza/CatFeeder.git

cd CatFeeder
```

---

## Pokretanje baze

```bash
docker compose up -d
```

---

## Pokretanje backend-a

```bash
cd backend

dotnet restore

dotnet ef database update

dotnet run
```

---

## Pokretanje mobilne aplikacije

```bash
cd frontend/mobile

flutter pub get

flutter run
```

Nakon pokretanja potrebno je u aplikaciji unijeti adresu backend servera.

---

# 📡 REST API

Glavni endpointi:

| Metoda | Endpoint | Opis |
|---------|----------|------|
| GET / POST / PUT / DELETE | `/api/cats` | Upravljanje mačkama |
| GET / POST | `/api/feedinglogs` | Historija hranjenja |
| GET / POST / PUT / DELETE | `/api/feedingschedules` | Upravljanje rasporedima |
| GET / POST | `/api/sensorreadings` | Očitavanja senzora |
| POST | `/api/ai/detect` | AI prepoznavanje mačke |
| POST | `/api/ai/chat` | AI Chat |

---

# 📈 Trenutni status projekta

## ✅ Implementirano

- ASP.NET Core Web API
- Flutter mobilna aplikacija
- SQL Server
- Docker podrška
- Upravljanje mačkama
- Rasporedi hranjenja
- Historija hranjenja
- Više mačaka
- Dashboard
- AI prepoznavanje mačke
- AI Chat
- AI analiza hranjenja
- Lokalne notifikacije

---

## 🚧 U razvoju

- ESP32 firmware
- Fizička montaža hranilice
- Potpuna integracija senzora
- Automatsko dopunjavanje vode

---

# 📸 Screenshotovi

> Screenshotovi mobilne aplikacije i fotografije hardvera bit će dodani nakon završetka razvoja.

---

# 📄 Licenca

Ovaj projekat je objavljen pod **MIT licencom**.

---

# 👨‍💻 Autor

**Asad Vejzović**

GitHub: https://github.com/asadevejza

---

⭐ Ako vam se projekat sviđa ili vam je bio koristan, ostavite **Star** na GitHub repozitoriju.