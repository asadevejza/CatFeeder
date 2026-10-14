using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CatFeeder.Data.Migrations
{
    /// <inheritdoc />
    public partial class FeedingCommandCatInfo : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "CatId",
                table: "FeedingCommands",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "PortionGrams",
                table: "FeedingCommands",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "ScheduleId",
                table: "FeedingCommands",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TriggeredBy",
                table: "FeedingCommands",
                type: "text",
                nullable: false,
                defaultValue: "");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CatId",
                table: "FeedingCommands");

            migrationBuilder.DropColumn(
                name: "PortionGrams",
                table: "FeedingCommands");

            migrationBuilder.DropColumn(
                name: "ScheduleId",
                table: "FeedingCommands");

            migrationBuilder.DropColumn(
                name: "TriggeredBy",
                table: "FeedingCommands");
        }
    }
}
