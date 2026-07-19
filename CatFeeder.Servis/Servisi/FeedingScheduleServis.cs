using CatFeeder.Data;
using CatFeeder.Data.Modeli;
using Microsoft.EntityFrameworkCore;

namespace CatFeeder.Servis.Servisi
{
    public class FeedingScheduleServis : BaseServis<FeedingSchedule>
    {
        public FeedingScheduleServis(CatFeederDbContext dbContext) : base(dbContext)
        {
        }

        public async Task<List<FeedingSchedule>> GetByCatIdAsync(int catId)
        {
            return await _dbContext.Set<FeedingSchedule>()
                .Where(s => s.CatId == catId)
                .ToListAsync();
        }
    }
}
