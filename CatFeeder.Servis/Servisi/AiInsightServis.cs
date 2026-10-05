using CatFeeder.Servis.Dtos;
using CatFeeder.Data.Modeli;

namespace CatFeeder.Servis.Servisi
{
    // Jednostavan statistički AI modul: detektuje odstupanja u hranjenju
    // (anomaly detection preko z-score), preporučuje dnevnu porciju
    // na osnovu RER (Resting Energy Requirement) formule iz veterinarske nauke,
    // i analizira trend tjelesne težine kroz posljednjih 30 dana.
    public class AiInsightServis
    {
        private readonly FeedingLogServis _feedingLogServis;
        private readonly FeedingScheduleServis _feedingScheduleServis;
        private readonly WeightLogServis _weightLogServis;

        public AiInsightServis(
            FeedingLogServis feedingLogServis,
            FeedingScheduleServis feedingScheduleServis,
            WeightLogServis weightLogServis)
        {
            _feedingLogServis = feedingLogServis;
            _feedingScheduleServis = feedingScheduleServis;
            _weightLogServis = weightLogServis;
        }

        public async Task<AiInsightDto> GenerateAsync(Cat cat)
        {
            var logs = await _feedingLogServis.GetByCatIdAsync(cat.Id);
            var schedules = await _feedingScheduleServis.GetByCatIdAsync(cat.Id);
            var weightLogs = await _weightLogServis.GetByCatIdAsync(cat.Id);

            var alerts = new List<string>();
            var now = DateTime.UtcNow;

            var dailyTotals = logs
                .Where(l => l.Timestamp >= now.AddDays(-14))
                .GroupBy(l => l.Timestamp.Date)
                .Select(g => new { Date = g.Key, Total = g.Sum(x => x.PortionGrams) })
                .OrderBy(x => x.Date)
                .ToList();

            double? avgDaily = null;
            double? lastDayTotal = null;
            double? deviationPercent = null;
            string regularity = "Nedovoljno podataka za procjenu";

            if (dailyTotals.Count >= 3)
            {
                avgDaily = dailyTotals.Average(d => d.Total);
                var variance = dailyTotals.Sum(d => Math.Pow(d.Total - avgDaily.Value, 2)) / dailyTotals.Count;
                var stdDev = Math.Sqrt(variance);

                lastDayTotal = dailyTotals.Last().Total;
                deviationPercent = avgDaily > 0
                    ? ((lastDayTotal.Value - avgDaily.Value) / avgDaily.Value) * 100
                    : 0;

                if (stdDev > 0)
                {
                    var zScore = (lastDayTotal.Value - avgDaily.Value) / stdDev;
                    if (zScore <= -1.5)
                        alerts.Add($"Mačka je posljednjeg dana pojela znatno manje nego obično ({lastDayTotal:F0}g naspram prosjeka {avgDaily:F0}g). Moguć znak bolesti ili kvara aparata.");
                    else if (zScore >= 1.5)
                        alerts.Add($"Mačka je posljednjeg dana pojela znatno više nego obično ({lastDayTotal:F0}g naspram prosjeka {avgDaily:F0}g).");
                }

                regularity = (stdDev / Math.Max(avgDaily.Value, 1)) < 0.2
                    ? "Redovno hranjenje"
                    : "Neredovno hranjenje — porcije dosta variraju";
            }

            if (schedules.Count > 0 && avgDaily is > 0)
            {
                var expectedPerDay = schedules.Sum(s => s.PortionGrams);
                if (expectedPerDay > 0)
                {
                    var adherence = (avgDaily.Value / expectedPerDay) * 100;
                    if (adherence < 70)
                        alerts.Add($"Stvarni dnevni unos je samo {adherence:F0}% planiranog rasporeda — provjeri da aparat ispravno izbacuje hranu.");
                }
            }

            double? recommendedDailyGrams = null;
            if (cat.WeightKg is > 0)
            {
                // RER (kcal/dan) = 70 * (tjelesna masa u kg)^0.75 — standardna veterinarska formula
                var rer = 70 * Math.Pow(cat.WeightKg.Value, 0.75);
                var activityFactor = cat.IsNeutered == true ? 1.2 : 1.4;
                var dailyKcal = rer * activityFactor;
                const double kcalPerGramDryFood = 3.6;
                recommendedDailyGrams = dailyKcal / kcalPerGramDryFood;

                if (avgDaily.HasValue && recommendedDailyGrams.HasValue)
                {
                    var diff = ((avgDaily.Value - recommendedDailyGrams.Value) / recommendedDailyGrams.Value) * 100;
                    if (diff > 25)
                        alerts.Add($"Mačka jede ~{diff:F0}% više od preporučene dnevne porcije za njenu težinu — rizik od gojaznosti.");
                    else if (diff < -25)
                        alerts.Add($"Mačka jede ~{Math.Abs(diff):F0}% manje od preporučene dnevne porcije za njenu težinu — rizik od pothranjenosti.");
                }
            }

            // Analiza trenda težine kroz zadnjih 30 dana
            double? weightTrendKg = null;
            double? weightTrendPercent = null;
            string? weightTrend = null;

            var recentWeights = weightLogs.Where(w => w.Date >= now.AddDays(-30)).ToList();
            if (recentWeights.Count >= 2)
            {
                var first = recentWeights.First();
                var last = recentWeights.Last();
                weightTrendKg = last.WeightKg - first.WeightKg;
                weightTrendPercent = first.WeightKg > 0 ? (weightTrendKg.Value / first.WeightKg) * 100 : 0;
                var daysSpan = Math.Max((last.Date - first.Date).Days, 1);

                if (weightTrendPercent >= 10)
                {
                    weightTrend = "Mačka dobija na težini";
                    alerts.Add($"{cat.Name} je dobila {weightTrendKg:F2}kg ({weightTrendPercent:F0}%) u zadnjih {daysSpan} dana — razmotri smanjenje porcija ili konsultaciju s veterinarom.");
                }
                else if (weightTrendPercent <= -10)
                {
                    weightTrend = "Mačka gubi na težini";
                    alerts.Add($"{cat.Name} je izgubila {Math.Abs(weightTrendKg.Value):F2}kg ({Math.Abs(weightTrendPercent.Value):F0}%) u zadnjih {daysSpan} dana — moguć znak bolesti, preporučuje se veterinarski pregled.");
                }
                else
                {
                    weightTrend = "Težina je stabilna";
                }
            }
            else
            {
                weightTrend = "Nedovoljno mjerenja težine za procjenu trenda (treba bar 2 unosa)";
            }

            var summary = avgDaily.HasValue
                ? $"{cat.Name} u prosjeku pojede {avgDaily:F0}g dnevno" +
                  (recommendedDailyGrams.HasValue ? $", preporučeno je ~{recommendedDailyGrams:F0}g dnevno. " : ". ") +
                  regularity + "."
                : "Nema dovoljno podataka o hranjenju za analizu. Potrebno je bar 3 dana zapisa.";

            return new AiInsightDto(
                cat.Id,
                cat.Name,
                now,
                avgDaily,
                recommendedDailyGrams,
                lastDayTotal,
                deviationPercent,
                regularity,
                alerts,
                summary,
                weightTrendKg,
                weightTrendPercent,
                weightTrend
            );
        }
    }
}