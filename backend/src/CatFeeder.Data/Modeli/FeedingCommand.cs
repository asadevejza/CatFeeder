using System;
using System.Collections.Generic;
using System.Text;

namespace CatFeeder.Data.Modeli
{
    public class FeedingCommand
    {
        public int Id { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public bool Executed { get; set; } = false;

        public int DurationSeconds { get; set; } = 2;

        // Nova polja
        public int? CatId { get; set; }
        public int PortionGrams { get; set; }
        public string TriggeredBy { get; set; } = "Manual (App)";
        public int? ScheduleId { get; set; }
        public double? ActualPortionGrams { get; set; }
    }
}
