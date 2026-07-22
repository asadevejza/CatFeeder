using CatFeeder.Servis.Servisi;
using Microsoft.AspNetCore.Mvc;
using CatFeeder.Data.Modeli;
using CatFeeder.Api.Dtos;

namespace CatFeeder.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class FeedingSchedulesController : ControllerBase
    {
        private readonly FeedingScheduleServis _scheduleServis;
        private readonly CatServis _catServis;

        public FeedingSchedulesController(FeedingScheduleServis scheduleServis, CatServis catServis)
        {
            _scheduleServis = scheduleServis;
            _catServis = catServis;
        }

        private static FeedingScheduleDto ToDto(FeedingSchedule s) => new(s.Id, s.CatId, s.Time, s.PortionGrams, s.DaysOfWeek);

        [HttpGet]
        public async Task<ActionResult<List<FeedingScheduleDto>>> GetSchedules()
        {
            var schedules = await _scheduleServis.GetAllAsync();
            return schedules.Select(ToDto).ToList();
        }

        [HttpGet("cat/{catId}")]
        public async Task<ActionResult<List<FeedingScheduleDto>>> GetByCatId(int catId)
        {
            var schedules = await _scheduleServis.GetByCatIdAsync(catId);
            return schedules.Select(ToDto).ToList();
        }

        [HttpPost]
        public async Task<ActionResult<FeedingScheduleDto>> CreateSchedule(FeedingScheduleCreateDto dto)
        {
            if (dto.PortionGrams <= 0)
                return BadRequest(new { error = "Količina hrane mora biti veća od 0." });

            var cat = await _catServis.GetByIdAsync(dto.CatId);
            if (cat == null)
                return BadRequest(new { error = $"Mačka sa ID {dto.CatId} ne postoji." });

            var schedule = new FeedingSchedule
            {
                CatId = dto.CatId,
                Time = dto.Time,
                PortionGrams = dto.PortionGrams,
                DaysOfWeek = dto.DaysOfWeek,
            };

            await _scheduleServis.AddAsync(schedule);

            return CreatedAtAction(nameof(GetSchedules), new { id = schedule.Id }, ToDto(schedule));
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateSchedule(int id, FeedingScheduleUpdateDto dto)
        {
            if (dto.PortionGrams <= 0)
                return BadRequest(new { error = "Količina hrane mora biti veća od 0." });

            var existing = await _scheduleServis.GetByIdAsync(id);
            if (existing == null) return NotFound();

            var cat = await _catServis.GetByIdAsync(dto.CatId);
            if (cat == null)
                return BadRequest(new { error = $"Mačka sa ID {dto.CatId} ne postoji." });

            existing.CatId = dto.CatId;
            existing.Time = dto.Time;
            existing.PortionGrams = dto.PortionGrams;
            existing.DaysOfWeek = dto.DaysOfWeek;

            await _scheduleServis.UpdateAsync(existing);
            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteSchedule(int id)
        {
            var schedule = await _scheduleServis.GetByIdAsync(id);
            if (schedule == null) return NotFound();

            await _scheduleServis.ObrisiAsync(schedule);
            return NoContent();
        }
    }
}
