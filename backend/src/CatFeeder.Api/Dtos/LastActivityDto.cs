namespace CatFeeder.Api.Dtos
{
    public class LastActivityDto
    {
        public DateTime? LastFeedingAt { get; set; }
        public double? HoursSinceLastFeeding { get; set; }
        public bool IsOverdue { get; set; }
    }
}