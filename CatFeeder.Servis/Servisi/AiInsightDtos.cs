namespace CatFeeder.Servis.Dtos
{
    public record AiInsightDto(
         int CatId,
         string CatName,
         DateTime GeneratedAt,
         double? AverageDailyPortionGrams,
         double? RecommendedDailyPortionGrams,
         double? LastDayPortionGrams,
         double? DeviationFromAveragePercent,
         string Regularity,
         List<string> Alerts,
         string Summary
     );
}
