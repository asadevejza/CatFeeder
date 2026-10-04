using CatFeeder.Servis.Servisi;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CatFeeder.Api.Controllers
{
    [ApiController]
    [Route("api/cats/{catId}/detect")]
    public class DetectionController : ControllerBase
    {
        private readonly CatDetectionServis _detectionServis;

        public DetectionController(CatDetectionServis detectionServis)
        {
            _detectionServis = detectionServis;
        }

        [HttpPost]
        public async Task<IActionResult> Detect(int catId, IFormFile photo)
        {
            if (photo == null || photo.Length == 0)
                return BadRequest("Nije poslana fotografija.");

            using var ms = new MemoryStream();
            await photo.CopyToAsync(ms);
            var imageBytes = ms.ToArray();

            var result = _detectionServis.Detect(imageBytes);

            return Ok(new
            {
                catDetected = result.CatDetected,
                confidence = result.Confidence,
                label = result.TopLabel
            });
        }
    }
}