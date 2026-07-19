using Microsoft.AspNetCore.Mvc;
using CatFeeder.Data.Modeli;
using CatFeeder.Servis.Servisi;

namespace CatFeeder.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class CatsController : ControllerBase
    {
        private readonly CatServis _catServis;

        public CatsController(CatServis catServis)
        {
            _catServis = catServis;
        }

        [HttpGet]
        public async Task<ActionResult<List<Cat>>> GetCats()
        {
            return await _catServis.GetAllAsync();
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<Cat>> GetCat(int id)
        {
            var cat = await _catServis.GetByIdAsync(id);
            if (cat == null) return NotFound();
            return cat;
        }

        [HttpPost]
        public async Task<ActionResult<Cat>> CreateCat(Cat cat)
        {
            if (string.IsNullOrWhiteSpace(cat.Name))
                return BadRequest(new { error = "Ime mačke je obavezno." });

            await _catServis.AddAsync(cat);
            return CreatedAtAction(nameof(GetCat), new { id = cat.Id }, cat);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateCat(int id, Cat cat)
        {
            if (id != cat.Id)
                return BadRequest(new { error = "ID u putanji i tijelu zahtjeva se ne poklapaju." });

            if (string.IsNullOrWhiteSpace(cat.Name))
                return BadRequest(new { error = "Ime mačke je obavezno." });

            var existing = await _catServis.GetByIdAsync(id);
            if (existing == null) return NotFound();

            await _catServis.UpdateAsync(cat);
            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteCat(int id)
        {
            var cat = await _catServis.GetByIdAsync(id);
            if (cat == null) return NotFound();

            await _catServis.ObrisiAsync(cat);
            return NoContent();
        }
    }
}
