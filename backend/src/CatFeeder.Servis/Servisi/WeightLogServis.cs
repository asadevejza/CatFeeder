using CatFeeder.Data;
using CatFeeder.Data.Modeli;
using Microsoft.EntityFrameworkCore;

namespace CatFeeder.Servis.Servisi
{
    public class WeightLogServis : BaseServis<WeightLog>
    {
        public WeightLogServis(CatFeederDbContext dbContext) : base(dbContext)
        {
        }

        public async Task<List<WeightLog>> GetByCatIdAsync(int catId)
        {
            return await _dbContext.Set<WeightLog>()
                .Where(log => log.CatId == catId)
                .OrderBy(log => log.Date)
                .ToListAsync();
        }
    }
}