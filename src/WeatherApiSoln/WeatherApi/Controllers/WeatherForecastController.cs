using Microsoft.AspNetCore.Mvc;
using System.Reflection;

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
            // get version from assembly
            var version = Assembly.GetExecutingAssembly().GetName().Version;
            _logger.LogInformation($"WeatherForecastController version {version}");
        }

        [HttpGet(Name = "GetWeatherForecast")]
        public IEnumerable<WeatherForecast> Get()
        {
            // get version from assembly
            var version = Assembly.GetExecutingAssembly().GetName().Version;
            _logger.LogInformation($"WeatherForecastController version {version}");

            //add custom trace log for application insights
            _logger.LogInformation("GetWeatherForecast called");
            _logger.LogDebug($"Debug {version}");
            _logger.LogInformation($"Information {version}");
            _logger.LogWarning($"Warning {version}");
            _logger.LogError($"Error {version}");
            _logger.LogCritical($"Critical {version}");

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
