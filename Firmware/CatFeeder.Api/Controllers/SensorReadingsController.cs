using CatFeeder.Data.Modeli;
using CatFeeder.Servis.Servisi;
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

        // 1. Dobavi sva očitavanja (npr. za prikaz grafikona na frontend-u)
        [HttpGet]
        public async Task<ActionResult<List<SensorReading>>> GetAll()
        {
            return await _sensorServis.GetAllAsync();
        }

        // 2. Endpoint koji će "hranilica" pozivati da pošalje nova očitavanja
        [HttpPost]
        public async Task<ActionResult<SensorReading>> PostReading(SensorReading reading)
        {
            if (reading.FoodLevelPercent < 0 || reading.FoodLevelPercent > 100)
                return BadRequest(new { error = "Nivo hrane mora biti između 0 i 100%." });

            // Ako klijent ne pošalje vrijeme, automatski postavljamo trenutno vrijeme
            if (reading.Timestamp == DateTime.MinValue)
            {
                reading.Timestamp = DateTime.Now;
            }

            await _sensorServis.AddAsync(reading);

            return CreatedAtAction(nameof(GetAll), new { id = reading.Id }, reading);
        }
    }
}
