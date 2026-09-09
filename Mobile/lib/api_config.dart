// Dijeljene konstante i podešavanja koja koristi skoro svaki ekran i servis.
import 'services/auth_service.dart';

// Koliko grama hrane stane u spremnik — placeholder dok ESP32 ne šalje pravo
// očitavanje nivoa. Slobodno promijeni na stvarni kapacitet tvog spremnika.
const int totalCapacityGrams = 2000;

// Produkcijska adresa backend servera na Railway-u.
const String defaultBaseUrl = 'https://catfeeder-production.up.railway.app/api';

// Obavezni API Ključ koji odgovara vrijednosti u Railway varijablama.
const String apiKey = '82fUSgPL8mUSKGoLvUYK1U9Bl7NraNrkbxhLqvgfTvU';

// Headeri koje SVAKI poziv ka backendu mora nositi (X-Api-Key) + Content-Type za pozive sa tijelom.
// Authorization (Bearer token) se dodaje automatski ako je korisnik prijavljen.
Map<String, String> apiHeaders({bool withJsonBody = false}) => {
      'X-Api-Key': apiKey,
      if (AuthService.currentToken != null) 'Authorization': 'Bearer ${AuthService.currentToken}',
      if (withJsonBody) 'Content-Type': 'application/json',
    };