using System;
using System.Collections.Generic;
using System.Text;

namespace CatFeeder.Data.Modeli
{
    public class Cat
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? RfidTag { get; set; }

        // Profil - sva polja opciona osim imena
        public string? Sex { get; set; }              // "Female" | "Male" | null
        public DateTime? BirthDate { get; set; }
        public string? Breed { get; set; }
        public bool? IsNeutered { get; set; }
        public double? WeightKg { get; set; }
        public string? Personality { get; set; }
        public string? Goals { get; set; }

        public ICollection<FeedingSchedule> FeedingSchedules { get; set; } = new List<FeedingSchedule>();
        public ICollection<FeedingLog> FeedingLogs { get; set; } = new List<FeedingLog>();
    }
}
