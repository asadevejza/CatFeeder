# ---- Build stage ----
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Kopiraj samo .csproj fajlove prvo, da Docker može keširati 'restore' korak
# dok ne promijeniš zavisnosti (brže rebuild-ove).
COPY CatFeeder.Api/CatFeeder.Api.csproj CatFeeder.Api/
COPY CatFeeder.Data/CatFeeder.Data.csproj CatFeeder.Data/
COPY CatFeeder.Servis/CatFeeder.Servis.csproj CatFeeder.Servis/
RUN dotnet restore CatFeeder.Api/CatFeeder.Api.csproj

# Sad kopiraj sav ostatak koda i izgradi.
COPY CatFeeder.Api/ CatFeeder.Api/
COPY CatFeeder.Data/ CatFeeder.Data/
COPY CatFeeder.Servis/ CatFeeder.Servis/
RUN dotnet publish CatFeeder.Api/CatFeeder.Api.csproj -c Release -o /app/publish --no-restore

# ---- Runtime stage (manji image, samo ono što treba da se pokrene) ----
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

ENTRYPOINT ["dotnet", "CatFeeder.Api.dll"]
