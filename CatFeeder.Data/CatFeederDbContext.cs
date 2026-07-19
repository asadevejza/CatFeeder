using CatFeeder.Data.Modeli;
using Microsoft.EntityFrameworkCore;

namespace CatFeeder.Data
{
    public class CatFeederDbContext : DbContext
    {
        public CatFeederDbContext(DbContextOptions<CatFeederDbContext> options) : base(options)
        {
        }

        public DbSet<Cat> Cats { get; set; }
        public DbSet<FeedingSchedule> FeedingSchedules { get; set; }
        public DbSet<FeedingLog> FeedingLogs { get; set; }
        public DbSet<SensorReading> SensorReadings { get; set; }
    }
}
