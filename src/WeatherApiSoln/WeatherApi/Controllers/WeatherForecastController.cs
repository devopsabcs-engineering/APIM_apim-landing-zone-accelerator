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
        private readonly string _version;

        public WeatherForecastController(ILogger<WeatherForecastController> logger)
        {
            _logger = logger;
            // get version from assembly
            _version = Assembly.GetExecutingAssembly().GetName().Version.ToString();
            _logger.LogInformation($"WeatherForecastController version {_version}");
        }

        [HttpGet(Name = "GetWeatherForecast")]
        public IEnumerable<WeatherForecast> Get()
        {
            // get version from assembly
            _logger.LogInformation($"WeatherForecastController version {_version}");

            //add custom trace log for application insights
            _logger.LogInformation("GetWeatherForecast called");
            _logger.LogDebug($"Debug {_version}");
            _logger.LogInformation($"Information {_version}");
            _logger.LogWarning($"Warning {_version}");
            _logger.LogError($"Error {_version}");
            _logger.LogCritical($"Critical {_version}");

            return Enumerable.Range(1, 5).Select(index => new WeatherForecast
            {
                Date = DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
                TemperatureC = Random.Shared.Next(-20, 55),
                Summary = Summaries[Random.Shared.Next(Summaries.Length)],
                Version = _version
            })
            .ToArray();
        }
    }
}
