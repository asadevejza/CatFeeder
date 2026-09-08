using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CatFeeder.Api.Controllers
{
    // Namjenski javno dostupan endpoint (bez JWT-a) samo za provjeru da li je
    // backend dostupan sa mreže. X-Api-Key i dalje mora biti tačan (provjerava
    // se u middleware-u u Program.cs prije nego zahtjev uopšte stigne ovdje).
    [ApiController]
    [Route("api/[controller]")]
    [AllowAnonymous]
    public class HealthController : ControllerBase
    {
        [HttpGet]
        public IActionResult Get() => Ok(new { status = "ok" });
    }
}
