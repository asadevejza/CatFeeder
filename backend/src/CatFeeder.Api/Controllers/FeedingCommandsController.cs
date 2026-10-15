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
                durationSeconds = command.DurationSeconds,
                portionGrams = command.PortionGrams // <--- Ovdje šaljemo točne grame iz aplikacije
            });
        }

        // ESP32 -> Označava komandu kao izvršenu i automatski smanjuje nivo hrane

        [AllowAnonymous]
        [HttpPost("{id}/complete")]
        public async Task<IActionResult> Complete(
            int id,
            [FromBody] CompleteFeedingCommandDto? dto)
        {
            var command = await _db.FeedingCommands.FindAsync(id);

            if (command == null)
                return NotFound(new { error = "Komanda nije pronađena." });

            // Spriječi ponovno evidentiranje iste komande.
            if (command.Executed)
            {
                return Ok(new
                {
                    success = true,
                    alreadyCompleted = true
                });
            }

            double? actualGrams = dto?.ActualPortionGrams;

            // Rezervna vrijednost: tražena količina.
            // Ovo nije potvrđeno mjerenje vage.
            if (!actualGrams.HasValue && command.PortionGrams > 0)
                actualGrams = command.PortionGrams;

            if (actualGrams.HasValue &&
                (double.IsNaN(actualGrams.Value) ||
                 double.IsInfinity(actualGrams.Value) ||
                 actualGrams.Value < 0 ||
                 actualGrams.Value > 5000))
            {
                return BadRequest(new
                {
                    error = "Neispravna izmjerena količina."
                });
            }

            double? weight = dto?.FoodWeightGrams;

            if (weight.HasValue &&
                (double.IsNaN(weight.Value) ||
                 double.IsInfinity(weight.Value) ||
                 weight.Value < 0 ||
                 weight.Value > 100000))
            {
                return BadRequest(new
                {
                    error = "Neispravna težina hrane."
                });
            }

            command.ActualPortionGrams = actualGrams;

            // Označi komandu izvršenom.
            await _servis.CompleteAsync(id);

            // Ako imamo stvarnu težinu, ona je izvor istine.
            if (weight.HasValue)
            {
                const double maxCapacityGrams = 500.0;

                double foodPercent = Math.Clamp(
                    weight.Value / maxCapacityGrams * 100.0,
                    0.0,
                    100.0
                );

                var lastReading = await _db.SensorReadings
                    .OrderByDescending(s => s.Timestamp)
                    .FirstOrDefaultAsync();

                var newReading = new SensorReading
                {
                    FoodWeightGrams = weight.Value,
                    FoodLevelPercent = foodPercent,
                    WaterLevelPercent = lastReading?.WaterLevelPercent,
                    Temperature = lastReading?.Temperature,
                    Humidity = lastReading?.Humidity,
                    Timestamp = DateTime.UtcNow
                };

                _db.SensorReadings.Add(newReading);
            }
            else
            {
                // Bez očitanja vage zadrži postojeću logiku
                // i smanji nivo samo za ovu komandu.
                var lastReading = await _db.SensorReadings
                    .OrderByDescending(s => s.Timestamp)
                    .FirstOrDefaultAsync();

                if (lastReading != null && actualGrams.HasValue)
                {
                    const double maxCapacityGrams = 500.0;

                    double drop =
                        actualGrams.Value / maxCapacityGrams * 100.0;

                    var newReading = new SensorReading
                    {
                        FoodLevelPercent = Math.Clamp(
                            lastReading.FoodLevelPercent - drop,
                            0.0,
                            100.0
                        ),
                        FoodWeightGrams = lastReading.FoodWeightGrams.HasValue
                            ? Math.Max(
                                0,
                                lastReading.FoodWeightGrams.Value -
                                actualGrams.Value)
                            : null,
                        WaterLevelPercent = lastReading.WaterLevelPercent,
                        Temperature = lastReading.Temperature,
                        Humidity = lastReading.Humidity,
                        Timestamp = DateTime.UtcNow
                    };

                    _db.SensorReadings.Add(newReading);
                }
            }

            await _db.SaveChangesAsync();

            return Ok(new
            {
                success = true,
                actualPortionGrams = command.ActualPortionGrams,
                foodWeightGrams = weight
            });
        }

    }
}