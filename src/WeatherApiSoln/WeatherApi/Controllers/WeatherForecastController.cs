using Microsoft.AspNetCore.Mvc;
using Microsoft.VisualBasic;

namespace WeatherApi.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class WeatherForecastController : ControllerBase
    {
        private static readonly string[] Summaries = new[]
        {
            "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
        };

        private readonly ILogger<WeatherForecastController> _logger;

        public WeatherForecastController(ILogger<WeatherForecastController> logger)
        {
            _logger = logger;
        }

        [HttpGet(Name = "GetWeatherForecast")]
        public IEnumerable<WeatherForecast> Get()
        {
            var iteration = 4;

            //add custom trace log for application insights
            _logger.LogInformation("GetWeatherForecast called");
            _logger.LogDebug($"Debug {iteration}");
            _logger.LogInformation($"Information {iteration}");
            _logger.LogWarning($"Warning {iteration}");
            _logger.LogError($"Error {iteration}");
            _logger.LogCritical($"Critical {iteration}");

            return Enumerable.Range(1, 5).Select(index => new WeatherForecast
            {
                Date = DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
                TemperatureC = Random.Shared.Next(-20, 55),
                Summary = Summaries[Random.Shared.Next(Summaries.Length)]
            })
            .ToArray();
        }
    }
}
