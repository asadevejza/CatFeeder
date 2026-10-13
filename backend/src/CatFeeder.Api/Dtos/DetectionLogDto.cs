using System;

namespace CatFeeder.Api.Dtos
{
    public class DetectionLogDto
    {
        public int Id { get; set; }
        public bool CatDetected { get; set; }
        public double Confidence { get; set; }
        public string Label { get; set; } = string.Empty;
        public DateTime DetectedAt { get; set; }
    }
}