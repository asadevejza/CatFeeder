using CatFeeder.Data;
using CatFeeder.Data.Modeli;
using Microsoft.EntityFrameworkCore;

namespace CatFeeder.Servis.Servisi
{
    public class UserServis : BaseServis<User>
    {
        public UserServis(CatFeederDbContext dbContext) : base(dbContext)
        {
        }

        public async Task<User?> GetByUsernameAsync(string username)
        {
            return await _dbContext.Users
                .FirstOrDefaultAsync(u => u.Username.ToLower() == username.ToLower());
        }
    }
}
