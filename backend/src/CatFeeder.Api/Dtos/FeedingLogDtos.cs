using System;

namespace CatFeeder.Api.Dtos
{
    public record FeedingLogDto(int Id, int CatId, DateTime Timestamp, int PortionGrams, string TriggeredBy);

    public record FeedingLogCreateDto(int CatId, int PortionGrams, string TriggeredBy, DateTime? Timestamp);
}
