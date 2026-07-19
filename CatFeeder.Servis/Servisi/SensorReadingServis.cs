using CatFeeder.Data;
using CatFeeder.Data.Modeli;

namespace CatFeeder.Servis.Servisi
{
    public class SensorReadingServis : BaseServis<SensorReading>
    {
        public SensorReadingServis(CatFeederDbContext dbContext) : base(dbContext)
        {
        }
    }
}
