using System;
using System.Collections.Generic;
using System.Text;

namespace CatFeeder.Data.Modeli
{
    public class SensorReading
    {
        public int Id { get; set; }

        private DateTime _timestamp = DateTime.UtcNow;
        public DateTime Timestamp
        {
            get => _timestamp;
            set => _timestamp = DateTime.SpecifyKind(value, DateTimeKind.Utc);
        }

        public double FoodLevelPercent { get; set; }
        public double? WaterLevelPercent { get; set; }
        public double? Temperature { get; set; }
        public double? Humidity { get; set; }
        public double? FoodWeightGrams { get; set; }

    }
}