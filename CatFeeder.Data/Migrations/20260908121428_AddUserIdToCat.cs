using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CatFeeder.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddUserIdToCat : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "UserId",
                table: "Cats",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "UserId",
                table: "Cats");
        }
    }
}
