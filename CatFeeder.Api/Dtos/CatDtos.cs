namespace CatFeeder.Api.Dtos
{
    // Ono što frontend dobije nazad - ne izlaže EF navigacione kolekcije (FeedingLogs, FeedingSchedules)
    public record CatDto(int Id, string Name, string? RfidTag);

    // Ono što frontend šalje kad pravi novu mačku
    public record CatCreateDto(string Name, string? RfidTag);

    // Ono što frontend šalje kad uređuje postojeću mačku (Id dolazi iz rute, ne iz tijela)
    public record CatUpdateDto(string Name, string? RfidTag);
}
