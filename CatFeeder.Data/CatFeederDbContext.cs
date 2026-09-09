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
        public DbSet<User> Users { get; set; }
        public DbSet<WeightLog> WeightLogs { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Korisničko ime mora biti jedinstveno na nivou baze, ne samo provjereno u kodu.
            modelBuilder.Entity<User>()
                .HasIndex(u => u.Username)
                .IsUnique();
        }
    }
}
