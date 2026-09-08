using System;
using System.Security.Cryptography;

namespace CatFeeder.Servis.Servisi
{
    // Heširanje lozinki pomoću PBKDF2 (ugrađeno u .NET, bez dodatnih paketa).
    // Svaka lozinka dobije svoju nasumičnu "so" (salt) da dvije iste lozinke
    // nikad ne daju isti hash.
    public static class PasswordHasher
    {
        private const int SaltSize = 16;       // 128 bit
        private const int HashSize = 32;       // 256 bit
        private const int Iterations = 100_000; // preporučeni minimum za 2026.

        public static (string Hash, string Salt) HashPassword(string password)
        {
            var saltBytes = RandomNumberGenerator.GetBytes(SaltSize);
            var hashBytes = Rfc2898DeriveBytes.Pbkdf2(
                password,
                saltBytes,
                Iterations,
                HashAlgorithmName.SHA256,
                HashSize);

            return (Convert.ToBase64String(hashBytes), Convert.ToBase64String(saltBytes));
        }

        public static bool VerifyPassword(string password, string storedHash, string storedSalt)
        {
            var saltBytes = Convert.FromBase64String(storedSalt);
            var hashBytes = Rfc2898DeriveBytes.Pbkdf2(
                password,
                saltBytes,
                Iterations,
                HashAlgorithmName.SHA256,
                HashSize);

            var computedHash = Convert.ToBase64String(hashBytes);
            // Poređenje u konstantnom vremenu — sprječava "timing attack".
            return CryptographicOperations.FixedTimeEquals(
                Convert.FromBase64String(computedHash),
                Convert.FromBase64String(storedHash));
        }
    }
}
