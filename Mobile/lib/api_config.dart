// Dijeljene konstante i podešavanja koja koristi skoro svaki ekran i servis.

// Koliko grama hrane stane u spremnik — placeholder dok ESP32 ne šalje pravo
// očitavanje nivoa. Slobodno promijeni na stvarni kapacitet tvog spremnika.
const int totalCapacityGrams = 2000;

// Adresa backend servera dok se korisnik ne postavi svoju kroz Podešavanja.
// 10.0.2.2 je specijalna adresa koju Android Emulator koristi za "localhost" računara.
const String defaultBaseUrl = 'http://10.0.2.2:5103/api';

// Mora biti IDENTIČAN "ApiKey" vrijednosti u CatFeeder.Api/appsettings.json na backendu.
// Ako ih promijeniš, promijeni na oba mjesta.
const String apiKey = '82fUSgPL8mUSKGoLvUYK1U9Bl7NraNrkbxhLqvgfTvU';

// Headeri koje SVAKI poziv ka backendu mora nositi (X-Api-Key) + Content-Type za pozive sa tijelom.
Map<String, String> apiHeaders({bool withJsonBody = false}) => {
      'X-Api-Key': apiKey,
      if (withJsonBody) 'Content-Type': 'application/json',
    };
