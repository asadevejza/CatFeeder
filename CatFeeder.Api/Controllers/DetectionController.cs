using CatFeeder.Api.Dtos;
using CatFeeder.Data;
using CatFeeder.Data.Modeli;
using CatFeeder.Servis.Servisi;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CatFeeder.Api.Controllers
{
    [ApiController]
    [Route("api/cats/{catId}/detect")]
    public class DetectionController : ControllerBase
    {
        private readonly CatDetectionServis _detectionServis;
        private readonly CatFeederDbContext _db;

        public DetectionController(CatDetectionServis detectionServis, CatFeederDbContext db)
        {
            _detectionServis = detectionServis;
            _db = db;
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

            var log = new DetectionLog
            {
                CatId = catId,
                CatDetected = result.CatDetected,
                Confidence = result.Confidence,
                Label = result.TopLabel,
                DetectedAt = DateTime.UtcNow
            };
            _db.DetectionLogs.Add(log);
            await _db.SaveChangesAsync();

            return Ok(new
            {
                catDetected = result.CatDetected,
                confidence = result.Confidence,
                label = result.TopLabel,
                detectedAt = log.DetectedAt
            });
        }

        [HttpGet]
        [Route("/api/cats/{catId}/detections")]
        public async Task<IActionResult> GetHistory(int catId)
        {
            var logs = await _db.DetectionLogs
                .Where(l => l.CatId == catId)
                .OrderByDescending(l => l.DetectedAt)
                .Take(50)
                .Select(l => new DetectionLogDto
                {
                    Id = l.Id,
                    CatDetected = l.CatDetected,
                    Confidence = l.Confidence,
                    Label = l.Label,
                    DetectedAt = l.DetectedAt
                })
                .ToListAsync();

            return Ok(logs);
        }
    }
}