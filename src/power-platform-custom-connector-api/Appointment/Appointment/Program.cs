using Appointments.Interfaces;
using Appointments.Repositories;
using Appointments.Services;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices(services =>
    {
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();


        string connectionString = Environment.GetEnvironmentVariable("StorageConnectionString");
        string appointmentsTable = Environment.GetEnvironmentVariable("StorageAccountAppointmentsTable");

        // Registering the service with parameters
        services.AddSingleton<IAppointmentRepository>(new AppointmentRepository(connectionString, appointmentsTable));

        services.AddSingleton<AppointmentService>();
    })
    .Build();

host.Run();
