namespace CatFeeder.Api.Dtos;

public record CreateFeedingCommandDto(int DurationSeconds, int CatId, int PortionGrams);

public record FeedingCommandDto(
    int Id,
    bool Executed,
    int DurationSeconds,
    DateTime CreatedAt
);