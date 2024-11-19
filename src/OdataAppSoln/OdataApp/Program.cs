namespace OdataApp
{
    using Microsoft.AspNetCore.OData;
    using Microsoft.OData.ModelBuilder;
    using OdataApp.Models;
    public class Program
    {
        public static void Main(string[] args)
        {
            // Program.cs
            var builder = WebApplication.CreateBuilder(args);

            var modelBuilder = new ODataConventionModelBuilder();
            modelBuilder.EntityType<Order>();
            modelBuilder.EntitySet<Customer>("Customers");

            builder.Services.AddControllers().AddOData(
                options => options.Select().Filter().OrderBy().Expand().Count().SetMaxTop(null).AddRouteComponents(
                    "odata",
                    modelBuilder.GetEdmModel()));

            // add application insights telemetry
            builder.Services.AddApplicationInsightsTelemetry();

            var app = builder.Build();

            app.UseRouting();

            app.UseEndpoints(endpoints => endpoints.MapControllers());

            app.Run();
        }
    }
}
