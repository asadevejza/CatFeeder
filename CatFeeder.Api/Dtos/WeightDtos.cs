namespace CatFeeder.Api.Dtos
{
    public record WeightLogDto(int Id, int CatId, double WeightKg, DateTime Date);

    public class WeightLogCreateDto
    {
        public int CatId { get; set; }
        public double WeightKg { get; set; }
    }
}