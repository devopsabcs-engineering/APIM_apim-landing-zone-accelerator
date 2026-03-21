using System.Net;
using System.Reflection;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace Appointments
{
    public class Version
    {
        private readonly ILogger _logger;

        public Version(ILoggerFactory loggerFactory)
        {
            _logger = loggerFactory.CreateLogger<Version>();
        }

        [Function("Version")]
        public HttpResponseData Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "version")] HttpRequestData req)
        {
            var version = Assembly.GetExecutingAssembly().GetName().Version?.ToString();
            _logger.LogInformation("Version endpoint called. Version: {version}", version);

            var response = req.CreateResponse(HttpStatusCode.OK);
            response.Headers.Add("Content-Type", "text/plain; charset=utf-8");
            response.WriteString(version ?? "unknown");
            return response;
        }
    }
}
