using CatFeeder.Api.Dtos;
using CatFeeder.Data.Modeli;
using CatFeeder.Servis.Servisi;
using Microsoft.AspNetCore.Mvc;

namespace CatFeeder.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class WeightsController : ControllerBase
    {
        private readonly WeightLogServis _weightLogServis;
        private readonly CatServis _catServis;

        public WeightsController(WeightLogServis weightLogServis, CatServis catServis)
        {
            _weightLogServis = weightLogServis;
            _catServis = catServis;
        }

        private static WeightLogDto ToDto(WeightLog log) => new(log.Id, log.CatId, log.WeightKg, log.Date);

        // Flutter WeightHistoryService.syncWithServer poziva ovo
        [HttpGet("cat/{catId}")]
        public async Task<ActionResult<List<WeightLogDto>>> GetByCatId(int catId)
        {
            var logs = await _weightLogServis.GetByCatIdAsync(catId);
            return Ok(logs.Select(ToDto).ToList());
        }

        // Flutter WeightHistoryService.logWeight poziva ovo
        [HttpPost]
        public async Task<ActionResult<WeightLogDto>> CreateLog([FromBody] WeightLogCreateDto dto)
        {
            if (dto.WeightKg <= 0)
                return BadRequest(new { error = "Težina mora biti veća od 0." });

            var cat = await _catServis.GetByIdAsync(dto.CatId);
            if (cat == null)
                return BadRequest(new { error = $"Mačka sa ID {dto.CatId} ne postoji." });

            var log = new WeightLog
            {
                CatId = dto.CatId,
                WeightKg = dto.WeightKg,
                Date = DateTime.UtcNow
            };
            await _weightLogServis.AddAsync(log);

            return Ok(ToDto(log));
        }
    }
}