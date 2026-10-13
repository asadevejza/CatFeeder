using System;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using CatFeeder.Api.Dtos;
using CatFeeder.Data.Modeli;
using CatFeeder.Servis.Servisi;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;

namespace CatFeeder.Api.Controllers
{
    // Registracija i prijava. Ovi endpointi NE traže JWT (logično - tek ovdje
    // se dobija token), ali i dalje prolaze kroz X-Api-Key provjeru iz Program.cs
    // kao i sve ostalo pod /api.
    [ApiController]
    [Route("api/[controller]")]
    [AllowAnonymous]
    public class AuthController : ControllerBase
    {
        private readonly UserServis _userServis;
        private readonly IConfiguration _configuration;

        public AuthController(UserServis userServis, IConfiguration configuration)
        {
            _userServis = userServis;
            _configuration = configuration;
        }

        [HttpPost("register")]
        public async Task<ActionResult<AuthResponseDto>> Register(AuthRequestDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.Username) || string.IsNullOrWhiteSpace(dto.Password))
                return BadRequest(new { error = "Korisničko ime i lozinka su obavezni." });

            if (dto.Password.Length < 6)
                return BadRequest(new { error = "Lozinka mora imati bar 6 karaktera." });

            var existing = await _userServis.GetByUsernameAsync(dto.Username);
            if (existing != null)
                return Conflict(new { error = "Korisničko ime je već zauzeto." });

            var (hash, salt) = PasswordHasher.HashPassword(dto.Password);
            var user = new User
            {
                Username = dto.Username.Trim(),
                PasswordHash = hash,
                PasswordSalt = salt,
            };
            await _userServis.AddAsync(user);

            return Ok(BuildToken(user));
        }

        [HttpPost("login")]
        public async Task<ActionResult<AuthResponseDto>> Login(AuthRequestDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.Username) || string.IsNullOrWhiteSpace(dto.Password))
                return BadRequest(new { error = "Korisničko ime i lozinka su obavezni." });

            var user = await _userServis.GetByUsernameAsync(dto.Username);
            if (user == null || !PasswordHasher.VerifyPassword(dto.Password, user.PasswordHash, user.PasswordSalt))
                return Unauthorized(new { error = "Pogrešno korisničko ime ili lozinka." });

            return Ok(BuildToken(user));
        }

        private AuthResponseDto BuildToken(User user)
        {
            var jwtSection = _configuration.GetSection("Jwt");
            var secretKey = jwtSection["Secret"]
                ?? throw new InvalidOperationException("Jwt:Secret nije podešen u appsettings.json.");
            var issuer = jwtSection["Issuer"] ?? "CatFeederApi";
            var expiresMinutes = int.TryParse(jwtSection["ExpiresMinutes"], out var m) ? m : 60 * 24 * 30; // default 30 dana

            var expiresAt = DateTime.UtcNow.AddMinutes(expiresMinutes);

            var claims = new[]
            {
                new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
                new Claim(JwtRegisteredClaimNames.UniqueName, user.Username),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            };

            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey));
            var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var token = new JwtSecurityToken(
                issuer: issuer,
                audience: issuer,
                claims: claims,
                expires: expiresAt,
                signingCredentials: credentials);

            var tokenString = new JwtSecurityTokenHandler().WriteToken(token);

            return new AuthResponseDto(tokenString, user.Username, expiresAt);
        }
    }
}
