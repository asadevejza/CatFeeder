using CatFeeder.Api.Dtos;
using CatFeeder.Servis.Servisi;
using Microsoft.AspNetCore.Mvc;

namespace CatFeeder.Api.Controllers
{
    [ApiController]
    [Route("api/cats/{catId}/chat")]
    public class ChatController : ControllerBase
    {
        private readonly ChatServis _chatServis;

        public ChatController(ChatServis chatServis)
        {
            _chatServis = chatServis;
        }

        [HttpPost]
        public async Task<IActionResult> Chat(int catId, [FromBody] ChatRequestDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.Message))
                return BadRequest("Poruka ne može biti prazna.");

            try
            {
                var reply = await _chatServis.AskAsync(dto.Message, dto.CatName, dto.ExtraContext);
                return Ok(new ChatResponseDto { Reply = reply });
            }
            catch (Exception ex)
            {
                return StatusCode(502, $"Greška pri komunikaciji sa AI servisom: {ex.Message}");
            }
        }
    }
}