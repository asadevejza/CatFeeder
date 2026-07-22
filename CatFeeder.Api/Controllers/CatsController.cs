using Microsoft.AspNetCore.Mvc;
using CatFeeder.Data.Modeli;
using CatFeeder.Servis.Servisi;
using CatFeeder.Api.Dtos;

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

        private static CatDto ToDto(Cat cat) => new(cat.Id, cat.Name, cat.RfidTag);

        [HttpGet]
        public async Task<ActionResult<List<CatDto>>> GetCats()
        {
            var cats = await _catServis.GetAllAsync();
            return cats.Select(ToDto).ToList();
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<CatDto>> GetCat(int id)
        {
            var cat = await _catServis.GetByIdAsync(id);
            if (cat == null) return NotFound();
            return ToDto(cat);
        }

        [HttpPost]
        public async Task<ActionResult<CatDto>> CreateCat(CatCreateDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.Name))
                return BadRequest(new { error = "Ime mačke je obavezno." });

            var cat = new Cat { Name = dto.Name, RfidTag = dto.RfidTag };
            await _catServis.AddAsync(cat);

            return CreatedAtAction(nameof(GetCat), new { id = cat.Id }, ToDto(cat));
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateCat(int id, CatUpdateDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.Name))
                return BadRequest(new { error = "Ime mačke je obavezno." });

            var existing = await _catServis.GetByIdAsync(id);
            if (existing == null) return NotFound();

            existing.Name = dto.Name;
            existing.RfidTag = dto.RfidTag;
            await _catServis.UpdateAsync(existing);

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
