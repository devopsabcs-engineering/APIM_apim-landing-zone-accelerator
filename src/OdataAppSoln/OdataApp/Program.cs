namespace OdataApp
{
    using Microsoft.AspNetCore.OData;
    using Microsoft.EntityFrameworkCore;
    using Microsoft.OData.ModelBuilder;
    using OdataApp.Models;
    public class Program
    {
        public static void Main(string[] args)
        {
            // Program.cs
            var builder = WebApplication.CreateBuilder(args);

            var modelBuilder = new ODataConventionModelBuilder();
            modelBuilder.EntityType<Product>();
            modelBuilder.EntityType<Customer>();
            modelBuilder.EntityType<Order>();
            modelBuilder.EntitySet<Product>("Products");
            modelBuilder.EntitySet<Customer>("Customers");
            modelBuilder.EntitySet<Order>("Orders");

            builder.Services.AddControllers().AddOData(
                options => options.Select().Filter().OrderBy().Expand().Count().SetMaxTop(null).AddRouteComponents(
                    "odata",
                    modelBuilder.GetEdmModel()));

            builder.Services.AddDbContext<AppDbContext>(opt => opt.UseInMemoryDatabase("ODataAuthDemo"));

            // add application insights telemetry
            builder.Services.AddApplicationInsightsTelemetry();

            var app = builder.Build();

            app.UseRouting();

            app.UseEndpoints(endpoints => endpoints.MapControllers());

            app.Run();
        }
    }
}
