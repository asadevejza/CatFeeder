namespace CatFeeder.Api.Dtos
{
    public class MeowTriggerDto
    {
        public int CatId { get; set; }
        public double AudioVolumeLevel { get; set; } // Opcionalno: jačina zvuka izmjerena na ESP32
    }
    public class MeowTriggerResponseDto
    {
        public bool Triggered { get; set; }
        public bool DispenseFood { get; set; }
        public string Message { get; set; } = string.Empty;
    }
}