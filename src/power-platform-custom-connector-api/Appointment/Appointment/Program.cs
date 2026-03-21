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

        services.AddSingleton<TableServiceClient>(sp =>
        {
            string storageAccountName = Environment.GetEnvironmentVariable("StorageAccountName") ?? "";
            string managedIdentityClientId = Environment.GetEnvironmentVariable("MANAGED_IDENTITY_CLIENT_ID");

            var credentialOptions = new DefaultAzureCredentialOptions
            {
                ExcludeSharedTokenCacheCredential = true,
                ExcludeVisualStudioCodeCredential = true,
                ExcludeVisualStudioCredential = true,
                ExcludeInteractiveBrowserCredential = true
            };

            if (!string.IsNullOrEmpty(managedIdentityClientId))
            {
                credentialOptions.ManagedIdentityClientId = managedIdentityClientId;
            }

            var credential = new DefaultAzureCredential(credentialOptions);

            return new TableServiceClient(
                new Uri($"https://{storageAccountName}.table.core.windows.net"),
                credential);
        });

        services.AddSingleton<IAppointmentRepository>(sp =>
        {
            string appointmentsTable = Environment.GetEnvironmentVariable("StorageAccountAppointmentsTable") ?? "Appointments";
            var tableServiceClient = sp.GetRequiredService<TableServiceClient>();
            return new AppointmentRepository(tableServiceClient, appointmentsTable);
        });

        services.AddSingleton<AppointmentService>();
    })
    .Build();

host.Run();
