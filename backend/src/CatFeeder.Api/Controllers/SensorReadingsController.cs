using CatFeeder.Data.Modeli;
using CatFeeder.Servis.Servisi;
using CatFeeder.Api.Dtos;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;

namespace CatFeeder.Api.Controllers
{
    [ApiController]
    [AllowAnonymous]
    [Route("api/[controller]")]
    public class SensorReadingsController : ControllerBase
    {
        private readonly SensorReadingServis _sensorServis;

        public SensorReadingsController(SensorReadingServis sensorServis)
        {
            _sensorServis = sensorServis;
        }

        private static SensorReadingDto ToDto(SensorReading r) =>
            new(r.Id,r.Timestamp,
        r.FoodLevelPercent,
        r.WaterLevelPercent,
        r.Temperature,
        r.Humidity,
        r.FoodWeightGrams);

        // 1. Dobavi sva očitavanja (npr. za prikaz grafikona na frontend-u)
        [Authorize]
        [HttpGet]
        public async Task<ActionResult<List<SensorReadingDto>>> GetAll()
        {
            var readings = await _sensorServis.GetAllAsync();
            return readings.Select(ToDto).ToList();
        }

        // 2. Endpoint koji će "hranilica" pozivati da pošalje nova očitavanja
        [AllowAnonymous]
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
                Timestamp = dto.Timestamp ?? DateTime.UtcNow, // Preporučeno da bude UTC
                FoodWeightGrams = dto.FoodWeightGrams
            };

            await _sensorServis.AddAsync(reading);

            return CreatedAtAction(nameof(GetAll), new { id = reading.Id }, ToDto(reading));
        }

        // 3. Novi endpoint za provjeru statusa uređaja (Online / Offline)
        [AllowAnonymous]
        [HttpGet("status")]
        public async Task<IActionResult> GetDeviceStatus()
        {
            var readings = await _sensorServis.GetAllAsync();
            var lastReading = readings.OrderByDescending(r => r.Timestamp).FirstOrDefault();

            if (lastReading == null)
            {
                return Ok(new { isOnline = false, message = "🔴 Device Offline (Nema podataka)" });
            }

            // Izračunaj razliku u vremenu
            var timeDifference = DateTime.UtcNow - lastReading.Timestamp;

            if (timeDifference.TotalMinutes > 2)
            {
                return Ok(new { isOnline = false, message = "🔴 Device Offline" });
            }

            return Ok(new { isOnline = true, message = "🟢 Device Online" });
        }
    }
}