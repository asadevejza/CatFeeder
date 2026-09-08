using System;

namespace CatFeeder.Data.Modeli
{
    // Korisnički nalog za prijavu u aplikaciju. Lozinka se nikad ne čuva
    // u čistom tekstu — samo PBKDF2 hash + so (vidi PasswordHasher u
    // CatFeeder.Servis).
    public class User
    {
        public int Id { get; set; }
        public string Username { get; set; } = string.Empty;
        public string PasswordHash { get; set; } = string.Empty;
        public string PasswordSalt { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
