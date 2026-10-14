using CatFeeder.Api.Dtos;
using CatFeeder.Servis.Servisi;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CatFeeder.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class FeedingCommandsController : ControllerBase
    {
        private readonly FeedingCommandServis _servis;

        public FeedingCommandsController(FeedingCommandServis servis)
        {
            _servis = servis;
        }

        // Flutter -> Kreira novu komandu
        [Authorize]
        [HttpPost]
        public async Task<ActionResult<FeedingCommandDto>> Create(CreateFeedingCommandDto dto)
        {
            var command = await _servis.CreateAsync(dto.DurationSeconds);

            return Ok(new FeedingCommandDto(
                command.Id,
                command.Executed,
                command.DurationSeconds,
                command.CreatedAt
            ));
        }

        // ESP32 -> Provjerava ima li nova komanda
        [AllowAnonymous]
        [HttpGet("pending")]
        public async Task<ActionResult> GetPending()
        {
            var command = await _servis.GetPendingAsync();

            if (command == null)
            {
                return Ok(new
                {
                    execute = false
                });
            }

            return Ok(new
            {
                execute = true,
                id = command.Id,
                durationSeconds = command.DurationSeconds
            });
        }

        // ESP32 -> Označava komandu kao izvršenu
        [AllowAnonymous]
        [HttpPost("{id}/complete")]
        public async Task<IActionResult> Complete(int id)
        {
            await _servis.CompleteAsync(id);

            return Ok(new
            {
                success = true
            });
        }
    }
}