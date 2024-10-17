using AddressBook.Service.SOAP.Repositories;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using SoapCore;

namespace AddressBook.Service.SOAP
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            // Add services to the container.
            builder.Services.AddSoapCore();
            builder.Services.AddSingleton<PersonProfileRepository>();
            builder.Services.TryAddSingleton<PersonProfileService>();
            builder.Services.AddMvc();

            // application insights
            builder.Services.AddApplicationInsightsTelemetry(options =>
            {
                options.ConnectionString = builder.Configuration["ApplicationInsights:ConnectionString"];
            });
            builder.Services.AddApplicationInsightsTelemetry(builder.Configuration["ApplicationInsights:InstrumentationKey"]);

            var app = builder.Build();

            if (app.Environment.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }

            app.UseHttpsRedirection();
            app.UseRouting(); // This should be called before UseEndpoints
            app.UseAuthorization();

            app.UseEndpoints(endpoints =>
            {
                endpoints.UseSoapEndpoint<PersonProfileService>(
                    "/PersonProfileService.asmx",
                    new SoapEncoderOptions(),
                    SoapSerializer.XmlSerializer);
            });

            app.Run();
        }
    }
}