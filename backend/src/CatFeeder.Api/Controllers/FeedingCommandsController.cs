using CatFeeder.Api.Dtos;
using CatFeeder.Data;
using CatFeeder.Data.Modeli;
using CatFeeder.Servis.Servisi;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CatFeeder.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class FeedingCommandsController : ControllerBase
    {
        private readonly FeedingCommandServis _servis;
        private readonly CatFeederDbContext _db; // Dodali smo DbContext da možemo snimiti novo očitavanje

        public FeedingCommandsController(FeedingCommandServis servis, CatFeederDbContext db)
        {
            _servis = servis;
            _db = db;
        }

        // Flutter -> Kreira novu komandu
        [Authorize]
        [HttpPost]
        public async Task<ActionResult<FeedingCommandDto>> Create(CreateFeedingCommandDto dto)
        {
            var command = await _servis.CreateAsync(
                dto.DurationSeconds, dto.CatId, dto.PortionGrams, "Manual (App)");

            return Ok(new FeedingCommandDto(
                command.Id, command.Executed, command.DurationSeconds, command.CreatedAt));
        }

        // ESP32 -> Provjerava ima li nova komanda
        [AllowAnonymous]
        [HttpGet("pending")]
        public async Task<ActionResult> GetPending()
        {
            var command = await _servis.GetPendingAsync();

            if (command == null)
            {
                return Ok(new
                {
                    execute = false
                });
            }

            return Ok(new
            {
                execute = true,
                id = command.Id,
                durationSeconds = command.DurationSeconds
            });
        }

        // ESP32 -> Označava komandu kao izvršenu i automatski smanjuje nivo hrane
        [AllowAnonymous]
        [HttpPost("{id}/complete")]
        public async Task<IActionResult> Complete(int id)
        {
            // 1. Pronađi komandu prije nego je označimo kao izvršenu da znamo koliko grama je izbačeno
            var command = await _db.FeedingCommands.FindAsync(id);

            // 2. Označi komandu kao izvršenu preko servisa
            await _servis.CompleteAsync(id);

            if (command != null && command.PortionGrams > 0)
            {
                // 3. Uzmi posljednje očitavanje senzora da vidimo trenutni postotak
                var lastReading = await _db.SensorReadings
                    .OrderByDescending(s => s.Timestamp)
                    .FirstOrDefaultAsync();

                if (lastReading != null)
                {
                    // Pretpostavka: Recimo da puna posuda ima npr. 300 grama (ili prilagodi maksimalnom kapacitetu posude)
                    // Možemo umanjiti postotak srazmjerno izbačenim gramima, npr. svaki gram skida oko 0.33% ako je 300g max, 
                    // Ili ako želiš direktno od postotka oduzeti procenat:

                    // Primjer: Pretvorimo gramažu u procenat (ako je kapacitet posude npr. 500g)
                    double maxCapacityGrams = 500.0;
                    double percentageDrop = (command.PortionGrams / maxCapacityGrams) * 100.0;

                    double newFoodLevel = lastReading.FoodLevelPercent - percentageDrop;
                    if (newFoodLevel < 0) newFoodLevel = 0;

                    // 4. Kreiraj novo očitavanje sa smanjenim nivoom hrane (ostale senzore prekopiraj iz zadnjeg)
                    var newReading = new SensorReading
                    {
                        FoodLevelPercent = newFoodLevel,
                        WaterLevelPercent = lastReading.WaterLevelPercent,
                        Temperature = lastReading.Temperature,
                        Humidity = lastReading.Humidity,
                        Timestamp = DateTime.UtcNow
                    };

                    _db.SensorReadings.Add(newReading);
                    await _db.SaveChangesAsync();
                }
            }

            return Ok(new
            {
                success = true
            });
        }
    }
}