using CatFeeder.Data;
using Microsoft.EntityFrameworkCore;

namespace CatFeeder.Servis.Servisi
{
    public abstract class BaseServis<T> where T : class
    {
        protected readonly CatFeederDbContext _dbContext;

        protected BaseServis(CatFeederDbContext dbContext)
        {
            _dbContext = dbContext;
        }

        public async Task<List<T>> GetAllAsync()
        {
            return await _dbContext.Set<T>().ToListAsync();
        }

        public async Task<T?> GetByIdAsync(int id)
        {
            return await _dbContext.Set<T>().FindAsync(id);
        }

        public async Task AddAsync(T obj)
        {
            _dbContext.Set<T>().Add(obj);
            await _dbContext.SaveChangesAsync();
        }

        public async Task UpdateAsync(T obj)
        {
            _dbContext.ChangeTracker.Clear();
            _dbContext.Set<T>().Update(obj);
            await _dbContext.SaveChangesAsync();
        }

        public async Task ObrisiAsync(T obj)
        {
            _dbContext.Set<T>().Remove(obj);
            await _dbContext.SaveChangesAsync();
        }
    }
}
