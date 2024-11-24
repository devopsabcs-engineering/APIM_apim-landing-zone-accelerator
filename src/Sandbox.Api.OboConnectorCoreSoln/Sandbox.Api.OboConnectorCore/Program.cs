using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Identity.Web;
using Microsoft.OpenApi.Models;
using System.Reflection;

namespace Sandbox.Api.OboConnectorCore
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            // Add services to the container.
            builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddMicrosoftIdentityWebApi(builder.Configuration, "AzureAd")
            .EnableTokenAcquisitionToCallDownstreamApi()
            .AddMicrosoftGraph(builder.Configuration.GetSection("MicrosoftGraph"))
            .AddDownstreamApi(
                "DownstreamDataverseApi",
                builder.Configuration.GetSection("DownstreamDataverseApi")
            ).AddInMemoryTokenCaches();

            builder.Services.AddControllers();
            // Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
            builder.Services.AddEndpointsApiExplorer();
            //builder.Services.AddSwaggerGen();
            builder.Services.AddSwaggerGen(setupAction =>
            {
                setupAction.SwaggerDoc("v1", new OpenApiInfo
                {
                    Title = "Obo Connector Core Api",
                    Version = "v1",
                    Description = "Obo Connector Core Api",
                    Contact = new OpenApiContact
                    {
                        Name = "Tae Rim Han",
                        Email = "taerim.han@test.com",
                        Url = new Uri("https://taerimhan.com")
                    }
                });
                setupAction.EnableAnnotations();
                setupAction.AddSecurityDefinition("oauth2", new OpenApiSecurityScheme
                {
                    Type = SecuritySchemeType.OAuth2,
                    Flows = new OpenApiOAuthFlows
                    {
                        Implicit = new OpenApiOAuthFlow
                        {
                            AuthorizationUrl
                                = new Uri($"https://login.windows.net/{builder.Configuration["AzureAd:TenantId"]}/oauth2/authorize", UriKind.Absolute),
                            Scopes = new Dictionary<string, string>
                    {
                        { "user_impersonation", "Access Dataverse data" },
                        { "access_as_user", "Access MS Graph data" }
                    }
                        }
                    }
                });
                setupAction.AddSecurityRequirement(new OpenApiSecurityRequirement
                {
                    {
                        new OpenApiSecurityScheme()
                        {
                            Reference = new OpenApiReference
                            {
                                Type = ReferenceType.SecurityScheme,
                                Id = "oauth2"
                            }
                        },
                        new List<string>()
                    }
                });
                var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
                var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
                setupAction.IncludeXmlComments(xmlPath);
            });

            var app = builder.Build();

            // Configure the HTTP request pipeline.
            if (true)//app.Environment.IsDevelopment())
            {
                //app.UseSwagger();
                //app.UseSwaggerUI();
                app.UseSwagger(setupAction =>
                {
                    setupAction.SerializeAsV2 = true;
                    setupAction.PreSerializeFilters.Add((swagger, httpReq) =>
                    {
                        swagger.Servers = new List<OpenApiServer>
                        {
                            new OpenApiServer { Url = $"{httpReq.Scheme}://{httpReq.Host.Value}" }
                        };
                    });
                });
                app.UseSwaggerUI(setupAction =>
                {
                    setupAction.OAuthClientId(builder.Configuration["Client:ClientId"]);
                    setupAction.OAuthClientSecret(builder.Configuration["Client:ClientSecret"]);
                    setupAction.OAuthRealm(builder.Configuration["AzureAd:ClientId"]);
                    setupAction.OAuthAppName("Obo Connector Core Api");
                    setupAction.OAuthScopeSeparator(" ");
                    setupAction.OAuthAdditionalQueryStringParams(new Dictionary<string, string>
                    {
                        { "resource", builder.Configuration["AzureAd:ClientId"] }
                    });
                    setupAction.SwaggerEndpoint("/swagger/v1/swagger.json", "Obo Connector Core Api");
                    setupAction.RoutePrefix = string.Empty;
                });
            }

            app.UseHttpsRedirection();

            app.UseAuthentication();

            app.UseAuthorization();

            app.MapControllers();

            app.Run();
        }
    }
}
