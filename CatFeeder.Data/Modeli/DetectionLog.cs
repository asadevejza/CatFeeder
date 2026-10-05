using System;

namespace CatFeeder.Data.Modeli
{
    public class DetectionLog
    {
        public int Id { get; set; }
        public int CatId { get; set; }
        public bool CatDetected { get; set; }
        public double Confidence { get; set; }
        public string Label { get; set; } = string.Empty;
        public DateTime DetectedAt { get; set; } = DateTime.UtcNow;
    }
}