using CatFeeder.Servis.Servisi;
using Microsoft.AspNetCore.Mvc;
using CatFeeder.Data.Modeli;

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

        [HttpGet]
        public async Task<ActionResult<List<FeedingSchedule>>> GetSchedules()
        {
            return await _scheduleServis.GetAllAsync();
        }

        [HttpGet("cat/{catId}")]
        public async Task<ActionResult<List<FeedingSchedule>>> GetByCatId(int catId)
        {
            return await _scheduleServis.GetByCatIdAsync(catId);
        }

        [HttpPost]
        public async Task<ActionResult<FeedingSchedule>> CreateSchedule(FeedingSchedule schedule)
        {
            if (schedule.PortionGrams <= 0)
                return BadRequest(new { error = "Količina hrane mora biti veća od 0." });

            var cat = await _catServis.GetByIdAsync(schedule.CatId);
            if (cat == null)
                return BadRequest(new { error = $"Mačka sa ID {schedule.CatId} ne postoji." });

            // Osigurajmo da EF ne pokuša ponovo kreirati objekat mačke u bazi
            schedule.Cat = null;

            await _scheduleServis.AddAsync(schedule);

            return CreatedAtAction(nameof(GetSchedules), new { id = schedule.Id }, schedule);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateSchedule(int id, FeedingSchedule schedule)
        {
            if (id != schedule.Id)
                return BadRequest(new { error = "ID u putanji i tijelu zahtjeva se ne poklapaju." });

            if (schedule.PortionGrams <= 0)
                return BadRequest(new { error = "Količina hrane mora biti veća od 0." });

            var existing = await _scheduleServis.GetByIdAsync(id);
            if (existing == null) return NotFound();

            schedule.Cat = null;
            await _scheduleServis.UpdateAsync(schedule);
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
