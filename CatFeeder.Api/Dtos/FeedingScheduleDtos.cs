using System;

namespace CatFeeder.Api.Dtos
{
    public record FeedingScheduleDto(int Id, int CatId, TimeSpan Time, int PortionGrams, string DaysOfWeek);

    public record FeedingScheduleCreateDto(int CatId, TimeSpan Time, int PortionGrams, string DaysOfWeek);

    public record FeedingScheduleUpdateDto(int CatId, TimeSpan Time, int PortionGrams, string DaysOfWeek);
}
