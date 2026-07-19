using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CatFeeder.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddWaterLevelToSensorReadings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "WaterLevelPercent",
                table: "SensorReadings",
                type: "float",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "WaterLevelPercent",
                table: "SensorReadings");
        }
    }
}
