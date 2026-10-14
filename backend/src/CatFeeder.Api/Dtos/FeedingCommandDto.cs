namespace CatFeeder.Api.Dtos;

public record CreateFeedingCommandDto(int DurationSeconds);

public record FeedingCommandDto(
    int Id,
    bool Executed,
    int DurationSeconds,
    DateTime CreatedAt
);