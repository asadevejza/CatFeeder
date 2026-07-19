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

        public ICollection<FeedingSchedule> FeedingSchedules { get; set; } = new List<FeedingSchedule>();
        public ICollection<FeedingLog> FeedingLogs { get; set; } = new List<FeedingLog>();
    }
}
