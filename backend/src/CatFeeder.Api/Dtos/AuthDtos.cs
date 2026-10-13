using System;

namespace CatFeeder.Api.Dtos
{
    // Ono što frontend šalje pri registraciji ili prijavi
    public record AuthRequestDto(
        string Username,
        string Password
    );

    // Ono što frontend dobije nazad poslije uspješne registracije/prijave
    public record AuthResponseDto(
        string Token,
        string Username,
        DateTime ExpiresAt
    );
}
