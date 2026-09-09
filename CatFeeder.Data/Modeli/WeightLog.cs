using System;
using System.Collections.Generic;
using System.Text;

namespace CatFeeder.Data.Modeli
{
    public class WeightLog
    {
        public int Id { get; set; }
        public int CatId { get; set; }
        public Cat? Cat { get; set; }
        public double WeightKg { get; set; }
        public DateTime Date { get; set; } = DateTime.UtcNow;
    }
}
