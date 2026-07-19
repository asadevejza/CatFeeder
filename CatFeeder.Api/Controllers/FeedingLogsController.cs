using CatFeeder.Data.Modeli;
using CatFeeder.Servis.Servisi;
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

        // 1. Dobavi kompletnu istoriju svih hranjenja
        [HttpGet]
        public async Task<ActionResult<List<FeedingLog>>> GetAll()
        {
            return await _logServis.GetAllAsync();
        }

        // 2. Dobavi istoriju hranjenja za tačno određenu mačku
        [HttpGet("cat/{catId}")]
        public async Task<ActionResult<List<FeedingLog>>> GetByCatId(int catId)
        {
            return await _logServis.GetByCatIdAsync(catId);
        }

        // 3. Zabilježi novo hranjenje
        [HttpPost]
        public async Task<ActionResult<FeedingLog>> CreateLog(FeedingLog log)
        {
            if (log.PortionGrams <= 0)
                return BadRequest(new { error = "Količina hrane mora biti veća od 0." });

            var cat = await _catServis.GetByIdAsync(log.CatId);
            if (cat == null)
                return BadRequest(new { error = $"Mačka sa ID {log.CatId} ne postoji." });

            log.Cat = null; // Spriječavamo EF da pokuša kreirati novu mačku

            if (log.Timestamp == DateTime.MinValue)
            {
                log.Timestamp = DateTime.Now;
            }

            await _logServis.AddAsync(log);

            return CreatedAtAction(nameof(GetAll), new { id = log.Id }, log);
        }
    }
}
