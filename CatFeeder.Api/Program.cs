using CatFeeder.Data;
using CatFeeder.Servis.Servisi;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Osiguravamo da server sluša na SVIM mrežnim interfejsima (0.0.0.0), ne samo na localhost —
// inače telefon na istoj WiFi mreži ne može da mu priđe. Ovo eksplicitno postavljanje je
// pouzdanije od oslanjanja na launchSettings.json profil, koji Visual Studio ponekad ne
// primijeni bez potpunog restarta same aplikacije.
builder.WebHost.UseUrls("http://0.0.0.0:5103");

// Add services to the container.
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        // Sigurnosna mreža: ako ikad učitaš povezane objekte (Cat -> FeedingLogs -> Cat...),
        // ovo sprječava beskonačnu petlju u JSON serijalizaciji umjesto da server padne.
        options.JsonSerializerOptions.ReferenceHandler =
            System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles;
    });

// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

// Baza se sada čita iz appsettings.json, ne iz koda
builder.Services.AddDbContext<CatFeederDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// Potrebno za Flutter Web (npr. pristup sa iPhone Safarija) — browseri blokiraju
// pozive ka drugoj adresi/portu osim ako server to eksplicitno dozvoli.
// Native mobilna app (Android/iOS build) ovo ne treba, ali web verzija da.
builder.Services.AddCors(options =>
{
    options.AddPolicy("DozvoliSve", policy =>
    {
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader();
    });
});

// Servisni sloj registrovan kroz DI umjesto ručnog "new" u svakom kontroleru
builder.Services.AddScoped<CatServis>();
builder.Services.AddScoped<FeedingLogServis>();
builder.Services.AddScoped<FeedingScheduleServis>();
builder.Services.AddScoped<SensorReadingServis>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

// Globalno hvatanje grešaka — umjesto generičkog 500 bez detalja,
// klijent (Flutter app) dobije čitljivu JSON poruku.
app.UseExceptionHandler(errorApp =>
{
    errorApp.Run(async context =>
    {
        context.Response.ContentType = "application/json";
        context.Response.StatusCode = StatusCodes.Status500InternalServerError;

        var feature = context.Features.Get<IExceptionHandlerFeature>();
        var message = app.Environment.IsDevelopment()
            ? feature?.Error.Message ?? "Nepoznata greška."
            : "Došlo je do greške na serveru. Pokušaj ponovo kasnije.";

        await context.Response.WriteAsJsonAsync(new { error = message });
    });
});

// Isključeno za development — Android emulator zove backend preko čistog HTTP-a (10.0.2.2),
// a redirect na HTTPS lomi poziv iz Flutter app-a. Vrati ovo kad app ide na pravi https server.
// app.UseHttpsRedirection();

app.UseCors("DozvoliSve");

app.UseAuthorization();

app.MapControllers();

app.Run();