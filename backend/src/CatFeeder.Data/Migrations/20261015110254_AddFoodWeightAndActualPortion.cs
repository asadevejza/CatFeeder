using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CatFeeder.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddFoodWeightAndActualPortion : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "FoodWeightGrams",
                table: "SensorReadings",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "ActualPortionGrams",
                table: "FeedingCommands",
                type: "double precision",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "FoodWeightGrams",
                table: "SensorReadings");

            migrationBuilder.DropColumn(
                name: "ActualPortionGrams",
                table: "FeedingCommands");
        }
    }
}
