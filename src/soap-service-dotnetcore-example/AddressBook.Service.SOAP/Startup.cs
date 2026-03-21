using AddressBook.Service.SOAP.Repositories;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using SoapCore;
using System.ServiceModel;

namespace AddressBook.Service.SOAP
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            services.AddSoapCore();
            services.AddSingleton<PersonProfileRepository>();
            services.TryAddSingleton<PersonProfileService>();
            services.AddSingleton<SoftwareVersionRepository>();
            services.TryAddSingleton<SoftwareVersionService>();
            services.AddMvc();
            // application insights
            services.AddApplicationInsightsTelemetry(options =>
            {
                options.ConnectionString = Configuration["ApplicationInsights:ConnectionString"];
            });
            services.AddApplicationInsightsTelemetry(Configuration["ApplicationInsights:InstrumentationKey"]);
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public virtual void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }

            app.UseHttpsRedirection();
            app.UseRouting();
            app.UseAuthorization();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllers();
            });

            app.UseSoapEndpoint<PersonProfileService>(options =>
            {
                options.Path = "/PersonProfileService.asmx";
                options.Binding = new BasicHttpsBinding();
            });
            app.UseSoapEndpoint<SoftwareVersionService>(options =>
            {
                options.Path = "/SoftwareVersionService.asmx";
                options.Binding = new BasicHttpsBinding();
            });
        }
    }
}