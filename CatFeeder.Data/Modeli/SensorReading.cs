using System;
using System.Collections.Generic;
using System.Text;

namespace CatFeeder.Data.Modeli
{
    public class SensorReading
    {
        public int Id { get; set; }
        public DateTime Timestamp { get; set; }
        public double FoodLevelPercent { get; set; }
        public double? WaterLevelPercent { get; set; }
        public double? Temperature { get; set; }
        public double? Humidity { get; set; }
    }
}