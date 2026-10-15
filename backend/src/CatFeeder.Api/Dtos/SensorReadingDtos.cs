using System;

namespace CatFeeder.Api.Dtos
{
    public record SensorReadingDto(int Id, DateTime Timestamp, double FoodLevelPercent, double? WaterLevelPercent, double? Temperature, double? Humidity, double? FoodWeightGrams) { };

    public record SensorReadingCreateDto(double FoodLevelPercent, double? WaterLevelPercent, double? Temperature, double? Humidity, DateTime? Timestamp) { public double? FoodWeightGrams { get; set; } };

}
