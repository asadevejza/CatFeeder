using CatFeeder.Data;
using CatFeeder.Data.Modeli;
using Microsoft.EntityFrameworkCore;

namespace CatFeeder.Servis.Servisi
{
    public class FeedingLogServis : BaseServis<FeedingLog>
    {
        public FeedingLogServis(CatFeederDbContext dbContext) : base(dbContext)
        {
        }

        public async Task<List<FeedingLog>> GetByCatIdAsync(int catId)
        {
            return await _dbContext.Set<FeedingLog>()
                .Where(log => log.CatId == catId)
                .ToListAsync();
        }
        public async Task<FeedingLog?> GetLastByCatIdAsync(int catId)
        {
            return await _dbContext.Set<FeedingLog>()
                .Where(log => log.CatId == catId)
                .OrderByDescending(log => log.Timestamp)
                .FirstOrDefaultAsync();
        }
    }
}
