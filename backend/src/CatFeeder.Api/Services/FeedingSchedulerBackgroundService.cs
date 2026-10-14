using CatFeeder.Data;
using CatFeeder.Data.Modeli;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace CatFeeder.Api.Services
{
    public class FeedingSchedulerBackgroundService : BackgroundService
    {
        private readonly IServiceScopeFactory _scopeFactory;

        // Ako je server bio ugašen u trenutku hranjenja, nadoknadi do 10 min kasnije
        private static readonly TimeSpan CatchUpWindow = TimeSpan.FromMinutes(10);

        public FeedingSchedulerBackgroundService(IServiceScopeFactory scopeFactory)
        {
            _scopeFactory = scopeFactory;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await CheckSchedulesAsync(stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Scheduler greška: {ex.Message}");
                }

                await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
            }
        }


        private async Task CheckSchedulesAsync(CancellationToken ct)
        {
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<CatFeederDbContext>();

            var tz = GetTimeZone();
            var nowLocal = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
            var todayName = nowLocal.DayOfWeek.ToString();   // "Monday", "Tuesday"...

            var schedules = await db.FeedingSchedules.ToListAsync(ct);

            foreach (var schedule in schedules)
            {
                // 1) Da li je raspored za današnji dan?
                var days = (schedule.DaysOfWeek ?? "")
                    .Split(',')
                    .Select(d => d.Trim());

                if (!days.Contains(todayName))
                    continue;

                // 2) Da li je vrijeme došlo (i nije prošlo previše)?
                var due = nowLocal.Date + schedule.Time;

                if (nowLocal >= due && nowLocal <= due + CatchUpWindow)
                {
                    // 3) Provjeri da li je komanda za ovaj raspored već kreirana danas (da se ne ponavlja u roku od 10 min)
                    var startOfDayLocal = nowLocal.Date;
                    var startOfDayUtc = TimeZoneInfo.ConvertTimeToUtc(startOfDayLocal, tz);

                    var alreadyTriggered = await db.FeedingCommands
                        .AnyAsync(c => c.ScheduleId == schedule.Id && c.CreatedAt >= startOfDayUtc, ct);

                    if (!alreadyTriggered)
                    {
                        // Kreiraj novu komandu za hranilicu
                        var command = new FeedingCommand
                        {
                            ScheduleId = schedule.Id,
                            CatId = schedule.CatId,
                            PortionGrams = schedule.PortionGrams,
                            DurationSeconds = (int)(schedule.PortionGrams * 0.5), // Prilagodi formulu po potrebi
                            Executed = false,
                            CreatedAt = DateTime.UtcNow,
                            TriggeredBy = "Scheduler"
                        };

                        db.FeedingCommands.Add(command);
                        await db.SaveChangesAsync(ct);

                        Console.WriteLine($"[SCHEDULER] Kreirana komanda za hranjenje (ScheduleId: {schedule.Id}) u {nowLocal}");
                    }
                }
            }
        }

        private TimeZoneInfo GetTimeZone()
        {
            try
            {
                // Za Windows: "Central Europe Standard Time", za Linux/Docker: "Europe/Sarajevo" ili "Europe/Zagreb"
                return TimeZoneInfo.FindSystemTimeZoneById("Europe/Sarajevo");
            }
            catch
            {
                return TimeZoneInfo.Utc;
            }
        }
    }
}