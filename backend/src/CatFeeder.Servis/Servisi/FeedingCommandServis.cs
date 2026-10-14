using CatFeeder.Data;
using CatFeeder.Data.Modeli;
using Microsoft.EntityFrameworkCore;

namespace CatFeeder.Servis.Servisi;

public class FeedingCommandServis
{
    private readonly CatFeederDbContext _db;
    private static readonly TimeSpan MaxPendingAge = TimeSpan.FromMinutes(10);

    public FeedingCommandServis(CatFeederDbContext db)
    {
        _db = db;
    }

    public async Task<FeedingCommand> CreateAsync(
        int seconds,
        int? catId = null,
        int portionGrams = 0,
        string triggeredBy = "Manual (App)",
        int? scheduleId = null)
    {
        var command = new FeedingCommand
        {
            DurationSeconds = seconds,
            CatId = catId,
            PortionGrams = portionGrams,
            TriggeredBy = triggeredBy,
            ScheduleId = scheduleId
        };

        _db.FeedingCommands.Add(command);
        await _db.SaveChangesAsync();
        return command;
    }

    public async Task<FeedingCommand?> GetPendingAsync()
    {
        var minCreated = DateTime.UtcNow - MaxPendingAge;

        return await _db.FeedingCommands
            .Where(x => !x.Executed && x.CreatedAt > minCreated)
            .OrderBy(x => x.CreatedAt)
            .FirstOrDefaultAsync();
    }

    public async Task CompleteAsync(int id)
    {
        var command = await _db.FeedingCommands.FindAsync(id);

        if (command == null || command.Executed)
            return;

        command.Executed = true;

        if (command.CatId != null)
        {
            _db.Set<FeedingLog>().Add(new FeedingLog
            {
                CatId = command.CatId.Value,
                PortionGrams = command.PortionGrams,
                TriggeredBy = command.TriggeredBy,
                Timestamp = DateTime.UtcNow
            });
        }

        await _db.SaveChangesAsync();
    }
}