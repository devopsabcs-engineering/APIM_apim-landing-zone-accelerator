using Appointments.Interfaces;
using Appointments.Repositories;
using Appointments.Services;
using Azure.Data.Tables;
using Azure.Identity;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices(services =>
    {
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();

        string appointmentsTable = Environment.GetEnvironmentVariable("StorageAccountAppointmentsTable");
        string storageAccountName = Environment.GetEnvironmentVariable("StorageAccountName");

        var tableServiceClient = new TableServiceClient(
            new Uri($"https://{storageAccountName}.table.core.windows.net"),
            new DefaultAzureCredential());

        services.AddSingleton<IAppointmentRepository>(new AppointmentRepository(tableServiceClient, appointmentsTable));

        services.AddSingleton<AppointmentService>();
    })
    .Build();

host.Run();
