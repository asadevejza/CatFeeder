using CatFeeder.Data;
using CatFeeder.Data.Modeli;
using Microsoft.EntityFrameworkCore;

namespace CatFeeder.Servis.Servisi;

public class FeedingCommandServis
{
    private readonly CatFeederDbContext _db;

    public FeedingCommandServis(CatFeederDbContext db)
    {
        _db = db;
    }

    public async Task<FeedingCommand> CreateAsync(int seconds)
    {
        var command = new FeedingCommand
        {
            DurationSeconds = seconds
        };

        _db.FeedingCommands.Add(command);

        await _db.SaveChangesAsync();

        return command;
    }

    public async Task<FeedingCommand?> GetPendingAsync()
    {
        return await _db.FeedingCommands
            .Where(x => !x.Executed)
            .OrderBy(x => x.CreatedAt)
            .FirstOrDefaultAsync();
    }

    public async Task CompleteAsync(int id)
    {
        var command = await _db.FeedingCommands.FindAsync(id);

        if (command == null)
            return;

        command.Executed = true;

        await _db.SaveChangesAsync();
    }
}