using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using CatFeeder.Servis.Servisi;

namespace CatFeeder.Api.Controllers
{
    [ApiController]
    [Route("api/cats/{catId}/insights")]
    public class InsightsController : ControllerBase
    {
        private readonly CatServis _catServis;
        private readonly AiInsightServis _aiInsightServis;

        public InsightsController(CatServis catServis, AiInsightServis aiInsightServis)
        {
            _catServis = catServis;
            _aiInsightServis = aiInsightServis;
        }

        private int CurrentUserId =>
            int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub")!);

        [HttpGet]
        public async Task<IActionResult> GetInsights(int catId)
        {
            var cat = await _catServis.GetByIdForUserAsync(catId, CurrentUserId);
            if (cat == null) return NotFound();

            var insight = await _aiInsightServis.GenerateAsync(cat);
            return Ok(insight);
        }
    }
}