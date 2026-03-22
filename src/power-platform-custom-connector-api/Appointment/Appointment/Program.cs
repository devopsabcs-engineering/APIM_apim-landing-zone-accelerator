using Appointments.Interfaces;
using Appointments.Repositories;
using Appointments.Services;
using Azure.Data.Tables;
using Azure.Identity;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = FunctionsApplication.CreateBuilder(args);

builder.ConfigureFunctionsWebApplication();

builder.Services.AddApplicationInsightsTelemetryWorkerService();
builder.Services.ConfigureFunctionsApplicationInsights();

builder.Services.AddSingleton<TableServiceClient>(sp =>
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

builder.Services.AddScoped<IAppointmentRepository>(sp =>
{
    string appointmentsTable = Environment.GetEnvironmentVariable("StorageAccountAppointmentsTable") ?? "Appointments";
    var tableServiceClient = sp.GetRequiredService<TableServiceClient>();
    return new AppointmentRepository(tableServiceClient, appointmentsTable);
});

builder.Services.AddScoped<AppointmentService>();

builder.Build().Run();
