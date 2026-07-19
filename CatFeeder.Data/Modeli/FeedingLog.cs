using System;
using System.Collections.Generic;
using System.Text;

namespace CatFeeder.Data.Modeli
{
    public class FeedingLog
    {
        public int Id { get; set; }
        public int CatId { get; set; }
        public Cat? Cat { get; set; }

        public DateTime Timestamp { get; set; }
        public int PortionGrams { get; set; }
        public string TriggeredBy { get; set; } = string.Empty;
    }
}
