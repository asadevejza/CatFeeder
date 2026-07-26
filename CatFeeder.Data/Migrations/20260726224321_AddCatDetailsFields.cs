using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CatFeeder.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddCatDetailsFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "BirthDate",
                table: "Cats",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Breed",
                table: "Cats",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Goals",
                table: "Cats",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsNeutered",
                table: "Cats",
                type: "bit",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Personality",
                table: "Cats",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Sex",
                table: "Cats",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "WeightKg",
                table: "Cats",
                type: "float",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "BirthDate",
                table: "Cats");

            migrationBuilder.DropColumn(
                name: "Breed",
                table: "Cats");

            migrationBuilder.DropColumn(
                name: "Goals",
                table: "Cats");

            migrationBuilder.DropColumn(
                name: "IsNeutered",
                table: "Cats");

            migrationBuilder.DropColumn(
                name: "Personality",
                table: "Cats");

            migrationBuilder.DropColumn(
                name: "Sex",
                table: "Cats");

            migrationBuilder.DropColumn(
                name: "WeightKg",
                table: "Cats");
        }
    }
}
