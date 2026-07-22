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
            return logs.Select(ToDto).ToList();
        }

        // 2. Dobavi istoriju hranjenja za tačno određenu mačku
        [HttpGet("cat/{catId}")]
        public async Task<ActionResult<List<FeedingLogDto>>> GetByCatId(int catId)
        {
            var logs = await _logServis.GetByCatIdAsync(catId);
            return logs.Select(ToDto).ToList();
        }

        // 3. Zabilježi novo hranjenje
        [HttpPost]
        public async Task<ActionResult<FeedingLogDto>> CreateLog(FeedingLogCreateDto dto)
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
                TriggeredBy = dto.TriggeredBy,
                Timestamp = dto.Timestamp ?? DateTime.Now,
            };

            await _logServis.AddAsync(log);

            return CreatedAtAction(nameof(GetAll), new { id = log.Id }, ToDto(log));
        }
    }
}
