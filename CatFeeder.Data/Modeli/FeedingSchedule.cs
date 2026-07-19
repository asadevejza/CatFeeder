using System;
using System.Collections.Generic;
using System.Text;

namespace CatFeeder.Data.Modeli
{
    public class FeedingSchedule
    {
        public int Id { get; set; }
        public int CatId { get; set; }
        public Cat? Cat { get; set; }
        public TimeSpan Time { get; set; }
        public int PortionGrams { get; set; }
        public string DaysOfWeek { get; set; } = string.Empty;
    }
}
