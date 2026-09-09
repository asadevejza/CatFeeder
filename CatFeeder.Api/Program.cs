using CatFeeder.Data;
using CatFeeder.Servis.Servisi;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Npgsql;
using Scalar.AspNetCore;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Server sluša na PORT varijabli sa Railway-a
var port = Environment.GetEnvironmentVariable("PORT") ?? "5103";
builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

builder.Services.AddControllers(options =>
{
    options.Filters.Add(new AuthorizeFilter());
})
.AddJsonOptions(options =>
{
    options.JsonSerializerOptions.ReferenceHandler =
        System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles;
});

builder.Services.AddOpenApi();

// Priprema i konverzija connection stringa za Npgsql (PostgreSQL)
var rawConnectionString = Environment.GetEnvironmentVariable("DATABASE_URL")
    ?? Environment.GetEnvironmentVariable("DATABASE_PUBLIC_URL")
    ?? builder.Configuration.GetConnectionString("DefaultConnection")
    ?? builder.Configuration["DATABASE_URL"]
    ?? builder.Configuration["ConnectionStrings:DefaultConnection"];

if (string.IsNullOrEmpty(rawConnectionString))
{
    var envKeys = string.Join(", ", Environment.GetEnvironmentVariables().Keys.Cast<string>());
    throw new InvalidOperationException($"Connection string za bazu nije pronađen! Dostupne env varijable u kontejneru su: [{envKeys}]");
}

string connString = rawConnectionString;

if (rawConnectionString.StartsWith("postgres://") || rawConnectionString.StartsWith("postgresql://"))
{
    var databaseUri = new Uri(rawConnectionString);
    var userInfo = databaseUri.UserInfo.Split(':', 2);

    var builderConn = new NpgsqlConnectionStringBuilder
    {
        Host = databaseUri.Host,
        Port = databaseUri.Port > 0 ? databaseUri.Port : 5432,
        Username = Uri.UnescapeDataString(userInfo[0]),
        Password = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : string.Empty,
        Database = databaseUri.AbsolutePath.TrimStart('/'),
        SslMode = SslMode.Require,
        TrustServerCertificate = true
    };

    connString = builderConn.ToString();
}

builder.Services.AddDbContext<CatFeederDbContext>(options =>
    options.UseNpgsql(connString, b => b.MigrationsAssembly(typeof(CatFeederDbContext).Assembly.FullName)));

builder.Services.AddCors(options =>
{
    options.AddPolicy("DozvoliSve", policy =>
    {
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader();
    });
});

var jwtSecret = builder.Configuration["Jwt:Secret"]
    ?? throw new InvalidOperationException("Jwt:Secret nije podešen u konfiguraciji.");
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "CatFeederApi";

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtIssuer,
            ValidateAudience = true,
            ValidAudience = jwtIssuer,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(2),
        };
    });

builder.Services.AddAuthorization();

builder.Services.AddScoped<CatServis>();
builder.Services.AddScoped<FeedingLogServis>();
builder.Services.AddScoped<FeedingScheduleServis>();
builder.Services.AddScoped<SensorReadingServis>();
builder.Services.AddScoped<UserServis>();

var app = builder.Build();

// Automatski primijeni EF Core migracije pri pokretanju
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<CatFeederDbContext>();
    db.Database.Migrate();
}

app.MapOpenApi();
app.MapScalarApiReference();

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

app.UseCors("DozvoliSve");

// Omogućava serviranje Flutter Web fajlova iz wwwroot foldera
app.UseDefaultFiles();
app.UseStaticFiles();

var configuredApiKey = app.Configuration["ApiKey"];
if (string.IsNullOrWhiteSpace(configuredApiKey))
{
    throw new InvalidOperationException("ApiKey nije podešen u konfiguraciji.");
}

// Middleware za provjeru X-Api-Key zaglavlja
app.Use(async (context, next) =>
{
    var path = context.Request.Path.Value ?? string.Empty;
    var isApiRoute = path.StartsWith("/api", StringComparison.OrdinalIgnoreCase);
    var isPreflight = HttpMethods.IsOptions(context.Request.Method);

    // Zaobilazimo provjeru ako je u pitanju bazna /api ruta
    var isRootApiRoute = path.Equals("/api", StringComparison.OrdinalIgnoreCase) ||
                         path.Equals("/api/", StringComparison.OrdinalIgnoreCase);

    // Primenjujemo X-Api-Key provjeru samo na /api pod-rute (osim ako nije opcija ili root)
    if (isApiRoute && !isPreflight && !isRootApiRoute)
    {
        var providedKey = context.Request.Headers["X-Api-Key"].ToString();
        if (string.IsNullOrEmpty(providedKey) || providedKey != configuredApiKey)
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(new { error = "Nevažeći ili nedostajući API ključ." });
            return;
        }
    }

    await next();
});

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Ako ruta nije API, preusmjeri na Flutter Web index.html
app.MapFallbackToFile("index.html");

app.Run();