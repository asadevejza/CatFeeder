using CatFeeder.Data.Modeli;
using CatFeeder.Servis.Servisi;
using CatFeeder.Api.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace CatFeeder.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class FeedingLogsController : ControllerBase
    {
        private readonly FeedingLogServis _logServis;
        private readonly CatServis _catServis;

        public FeedingLogsController(FeedingLogServis logServis, CatServis catServis)
        {
            _logServis = logServis;
            _catServis = catServis;
        }

        private static FeedingLogDto ToDto(FeedingLog log) => new(log.Id, log.CatId, log.Timestamp, log.PortionGrams, log.TriggeredBy);

        // 1. Dobavi kompletnu istoriju svih hranjenja
        [HttpGet]
        public async Task<ActionResult<List<FeedingLogDto>>> GetAll()
        {
            var logs = await _logServis.GetAllAsync();
            return Ok(logs.Select(ToDto).ToList());
        }

        // 2. Dobavi istoriju hranjenja za tačno određenu mačku
        [HttpGet("cat/{catId}")]
        public async Task<ActionResult<List<FeedingLogDto>>> GetByCatId(int catId)
        {
            var logs = await _logServis.GetByCatIdAsync(catId);
            return Ok(logs.Select(ToDto).ToList());
        }

        // 3. Zabilježi novo hranjenje
        [HttpPost]
        public async Task<ActionResult<FeedingLogDto>> CreateLog([FromBody] FeedingLogCreateDto dto)
        {
            if (dto.PortionGrams <= 0)
                return BadRequest(new { error = "Količina hrane mora biti veća od 0." });

            var cat = await _catServis.GetByIdAsync(dto.CatId);
            if (cat == null)
                return BadRequest(new { error = $"Mačka sa ID {dto.CatId} ne postoji." });

            var log = new FeedingLog
            {
                CatId = dto.CatId,
                PortionGrams = dto.PortionGrams,
                TriggeredBy = string.IsNullOrWhiteSpace(dto.TriggeredBy) ? "Manual" : dto.TriggeredBy,
                Timestamp = dto.Timestamp?.ToUniversalTime() ?? DateTime.UtcNow
            };

            await _logServis.AddAsync(log);

            return Ok(ToDto(log));
        }

        // 4. Provjeri kada je mačka zadnje hranjena (za upozorenje u appu)
        [HttpGet("cat/{catId}/last-activity")]
        public async Task<ActionResult<LastActivityDto>> GetLastActivity(int catId, [FromQuery] double overdueAfterHours = 10)
        {
            var last = await _logServis.GetLastByCatIdAsync(catId);
            if (last == null)
                return Ok(new LastActivityDto { LastFeedingAt = null, HoursSinceLastFeeding = null, IsOverdue = false });

            var hoursSince = (DateTime.UtcNow - last.Timestamp).TotalHours;
            return Ok(new LastActivityDto
            {
                LastFeedingAt = last.Timestamp,
                HoursSinceLastFeeding = hoursSince,
                IsOverdue = hoursSince >= overdueAfterHours
            });
        }

        // 5. Okidač za mjaukanje (Zvuk sa ESP32)
        [HttpPost("meow-trigger")]
        public async Task<ActionResult<MeowTriggerResponseDto>> HandleMeowTrigger([FromBody] MeowTriggerDto dto)
        {
            var cat = await _catServis.GetByIdAsync(dto.CatId);
            if (cat == null)
                return BadRequest(new { error = $"Mačka sa ID {dto.CatId} ne postoji." });

            // 1. Provjera Cooldown perioda (npr. minimalno 2 sata između obroka)
            var last = await _logServis.GetLastByCatIdAsync(dto.CatId);
            if (last != null)
            {
                var hoursSinceLast = (DateTime.UtcNow - last.Timestamp).TotalHours;
                if (hoursSinceLast < 2.0)
                {
                    return Ok(new MeowTriggerResponseDto
                    {
                        Triggered = false,
                        DispenseFood = false,
                        Message = $"Mjauk registrovan, ali je mačka nedavno jela (prije {hoursSinceLast:F1} sati). Cooldown aktivan."
                    });
                }
            }

            // 2. Ako je cooldown prošao, upisujemo novo hranjenje
            var log = new FeedingLog
            {
                CatId = dto.CatId,
                PortionGrams = 30, // Defaultna porcija ili izvuci iz postavki mačke
                TriggeredBy = "Audio-Detection (Meow)",
                Timestamp = DateTime.UtcNow
            };

            await _logServis.AddAsync(log);

            return Ok(new MeowTriggerResponseDto
            {
                Triggered = true,
                DispenseFood = true,
                Message = "Detektovano mjaukanje. Doziranje hrane je odobreno!"
            });
        }
    }
}