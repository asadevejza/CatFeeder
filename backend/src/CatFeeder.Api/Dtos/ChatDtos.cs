namespace CatFeeder.Api.Dtos
{
    public class ChatRequestDto
    {
        public string Message { get; set; } = string.Empty;
        public string? CatName { get; set; }
        public string? ExtraContext { get; set; }
    }

    public class ChatResponseDto
    {
        public string Reply { get; set; } = string.Empty;
    }
}