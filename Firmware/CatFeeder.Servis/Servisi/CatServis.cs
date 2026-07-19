using CatFeeder.Data;
using CatFeeder.Data.Modeli;

namespace CatFeeder.Servis.Servisi
{
    public class CatServis : BaseServis<Cat>
    {
        public CatServis(CatFeederDbContext dbContext) : base(dbContext)
        {
        }
    }
}
