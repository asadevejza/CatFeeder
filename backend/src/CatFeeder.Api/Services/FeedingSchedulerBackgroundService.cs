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
                    using var scope = _scopeFactory.CreateScope();

                    var db = scope.ServiceProvider.GetRequiredService<CatFeederDbContext>();

                    var schedules = await db.FeedingSchedules.ToListAsync(stoppingToken);

                    var now = DateTime.Now;

                    foreach (var schedule in schedules)
                    {
                        Console.WriteLine($"Raspored: {schedule.Time} | Trenutno: {now:HH:mm}");

                        if (schedule.Time.Hours == now.Hour &&
                            schedule.Time.Minutes == now.Minute)
                        {
                            Console.WriteLine("Vrijeme je za hranjenje!");

                            bool commandExists = await db.FeedingCommands
                                .AnyAsync(c => !c.Executed, stoppingToken);

                            if (!commandExists)
                            {
                                db.FeedingCommands.Add(new FeedingCommand
                                {
                                    DurationSeconds = 2,
                                    Executed = false,
                                    CreatedAt = DateTime.UtcNow
                                });

                                await db.SaveChangesAsync(stoppingToken);

                                Console.WriteLine("FeedingCommand kreiran.");
                            }
                            else
                            {
                                Console.WriteLine("Već postoji neizvršena komanda.");
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Scheduler greška: {ex.Message}");
                }

                await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
            }
        }
    }
}