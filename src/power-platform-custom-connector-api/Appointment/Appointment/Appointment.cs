using System.Net;
using Appointment.Models;
using System.Text.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using Appointments.Services;
using Appointments.Models;
using System.Collections.Concurrent;
using System.Reflection;

namespace Appointments
{
    public class Appointment
    {
        private readonly ILogger _logger;
        private readonly AppointmentService _appointmentService;
        private readonly string _version;

        public Appointment(ILoggerFactory loggerFactory, AppointmentService appointmentService)
        {
            _logger = loggerFactory.CreateLogger<Appointment>();
            _appointmentService = appointmentService;
            // get version from executing assembly
            _version = Assembly.GetExecutingAssembly().GetName().Version.ToString();
            _logger.LogInformation($"Version : {_version}");
        }

        [Function("Appointment")]
        public async Task<HttpResponseData> Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", "put", "post", "delete", Route = "Appointment/{customerId?}/{appointmentId?}")] HttpRequestData req,
            string? customerId, string? appointmentId)
        {
            _logger.LogInformation($"C# HTTP trigger function processed a request. (version: {_version})");

            var response = req.CreateResponse(HttpStatusCode.OK);
            response.Headers.Add("Content-Type", "text/plain; charset=utf-8");

            try
            {
                switch (req.Method.ToLower())
                {
                    case "get":
                        response = await HandleGetAsync(req, customerId, appointmentId);
                        break;
                    case "post":
                        response = await HandlePostAsync(req);
                        break;
                    case "put":
                        response = await HandlePutAsync(req);
                        break;
                    case "delete":
                        response = await HandleDeleteAsync(req, customerId, appointmentId);
                        break;
                    default:
                        response = req.CreateResponse(HttpStatusCode.MethodNotAllowed);
                        break;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"An error occurred while processing the request. (version: {_version})");
                response = req.CreateResponse(HttpStatusCode.InternalServerError);

                await response.WriteStringAsync($"An error has occurred. Error: {ex.Message}");
            }

            return response;
        }

        private async Task<HttpResponseData> HandleGetAsync(HttpRequestData req, string customerId, string appointmentId)
        {
            var queryParams = System.Web.HttpUtility.ParseQueryString(req.Url.Query);

            if (string.IsNullOrEmpty(customerId))
            {
                var response = req.CreateResponse(HttpStatusCode.BadRequest);
                await response.WriteStringAsync("Missing customerId.");
                return response;
            }

            if (string.IsNullOrEmpty(appointmentId))
            {
                var appointments = await _appointmentService.GetAppointmentsAsync(customerId);
                var response = req.CreateResponse(HttpStatusCode.OK);
                await response.WriteAsJsonAsync(appointments);
                _logger.LogInformation($"Retrieved appointments for customerId: {customerId}. (version: {_version})");
                return response;
            }
            else
            {
                var appointment = await _appointmentService.GetAppointmentAsync(customerId, appointmentId);
                var response = req.CreateResponse(HttpStatusCode.OK);
                await response.WriteAsJsonAsync(appointment);
                _logger.LogInformation($"Retrieved appointment for customerId: {customerId}, appointmentId: {appointmentId}. (version: {_version})");
                return response;
            }
        }

        private async Task<HttpResponseData> HandlePostAsync(HttpRequestData req)
        {
            var requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            var appointment = JsonSerializer.Deserialize<CustomerAppointment>(requestBody);

            await _appointmentService.CreateAppointmentAsync(appointment);

            var response = req.CreateResponse(HttpStatusCode.Created);
            await response.WriteStringAsync("Appointment created successfully.");
            _logger.LogInformation($"Created appointment for customerId: {appointment.CustomerId}. (version: {_version})");
            return response;
        }

        private async Task<HttpResponseData> HandlePutAsync(HttpRequestData req)
        {
            var requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            var appointment = JsonSerializer.Deserialize<CustomerAppointment>(requestBody);

            await _appointmentService.UpdateAppointmentAsync(appointment);

            var response = req.CreateResponse(HttpStatusCode.NoContent);
            _logger.LogInformation($"Updated appointment for customerId: {appointment.CustomerId}, appointmentId: {appointment.Id}. (version: {_version})");
            return response;
        }

        private async Task<HttpResponseData> HandleDeleteAsync(HttpRequestData req, string customerId, string appointmentId)
        {
            var queryParams = System.Web.HttpUtility.ParseQueryString(req.Url.Query);

            if (string.IsNullOrEmpty(customerId))
            {
                var response = req.CreateResponse(HttpStatusCode.BadRequest);
                await response.WriteStringAsync("Missing customerId.");
                return response;
            }
            else if (string.IsNullOrEmpty(appointmentId))
            {
                var response = req.CreateResponse(HttpStatusCode.BadRequest);
                await response.WriteStringAsync("Missing appointmentId.");
                return response;
            }
            else
            {
                await _appointmentService.DeleteAppointmentAsync(customerId, appointmentId);

                var response = req.CreateResponse(HttpStatusCode.OK);
                await response.WriteStringAsync("Appointment deleted successfully.");
                _logger.LogInformation($"Deleted appointment for customerId: {customerId}, appointmentId: {appointmentId}. (version: {_version})");
                return response;
            }
        }
    }

}