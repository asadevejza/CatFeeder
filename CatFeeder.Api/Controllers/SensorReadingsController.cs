using CatFeeder.Data.Modeli;
using CatFeeder.Servis.Servisi;
using CatFeeder.Api.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace CatFeeder.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SensorReadingsController : ControllerBase
    {
        private readonly SensorReadingServis _sensorServis;

        public SensorReadingsController(SensorReadingServis sensorServis)
        {
            _sensorServis = sensorServis;
        }

        private static SensorReadingDto ToDto(SensorReading r) =>
            new(r.Id, r.Timestamp, r.FoodLevelPercent, r.WaterLevelPercent, r.Temperature, r.Humidity);

        // 1. Dobavi sva očitavanja (npr. za prikaz grafikona na frontend-u)
        [HttpGet]
        public async Task<ActionResult<List<SensorReadingDto>>> GetAll()
        {
            var readings = await _sensorServis.GetAllAsync();
            return readings.Select(ToDto).ToList();
        }

        // 2. Endpoint koji će "hranilica" pozivati da pošalje nova očitavanja
        [HttpPost]
        public async Task<ActionResult<SensorReadingDto>> PostReading(SensorReadingCreateDto dto)
        {
            if (dto.FoodLevelPercent < 0 || dto.FoodLevelPercent > 100)
                return BadRequest(new { error = "Nivo hrane mora biti između 0 i 100%." });

            if (dto.WaterLevelPercent is < 0 or > 100)
                return BadRequest(new { error = "Nivo vode mora biti između 0 i 100%." });

            var reading = new SensorReading
            {
                FoodLevelPercent = dto.FoodLevelPercent,
                WaterLevelPercent = dto.WaterLevelPercent,
                Temperature = dto.Temperature,
                Humidity = dto.Humidity,
                Timestamp = dto.Timestamp ?? DateTime.Now,
            };

            await _sensorServis.AddAsync(reading);

            return CreatedAtAction(nameof(GetAll), new { id = reading.Id }, ToDto(reading));
        }
    }
}
