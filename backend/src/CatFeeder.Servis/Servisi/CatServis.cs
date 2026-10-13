using CatFeeder.Data;
using CatFeeder.Data.Modeli;
using Microsoft.EntityFrameworkCore;

namespace CatFeeder.Servis.Servisi
{
    public class CatServis : BaseServis<Cat>
    {
        public CatServis(CatFeederDbContext dbContext) : base(dbContext)
        {
        }

        // Samo mačke ulogovanog korisnika — ne sve mačke iz baze.
        public async Task<List<Cat>> GetAllForUserAsync(int userId) =>
            await _dbContext.Cats.Where(c => c.UserId == userId).ToListAsync();

        public async Task<Cat?> GetByIdForUserAsync(int id, int userId) =>
            await _dbContext.Cats.FirstOrDefaultAsync(c => c.Id == id && c.UserId == userId);
    }
}
