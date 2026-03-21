using Autofac;
using Autofac.Core;
using Autofac.Extensions.DependencyInjection;
using GraphQL;
using Microsoft.EntityFrameworkCore;
using MovieReviews.Database;
using MovieReviews.GraphQL;
using MovieReviews.Repository;
using System.Reflection;

var builder = WebApplication.CreateBuilder(args);

// Use Autofac for dependency injection
builder.Host.UseServiceProviderFactory(new AutofacServiceProviderFactory())
           .ConfigureContainer<ContainerBuilder>(containerBuilder =>
           {
               containerBuilder.RegisterType<MovieRepository>().As<IMovieRepository>().InstancePerLifetimeScope();
               containerBuilder.RegisterType<QueryObject>().AsSelf().SingleInstance().UsingConstructor(typeof(IMovieRepository));
               containerBuilder.RegisterType<MutationObject>().AsSelf().SingleInstance().UsingConstructor(typeof(IMovieRepository));
           });

// Add services to the container.

builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services
       .AddEntityFrameworkInMemoryDatabase()
       .AddDbContext<MovieContext>(context => { context.UseInMemoryDatabase("MovieDb"); });

// Adding Logging before calling AddGraphQL
builder.Services.AddLogging();


builder.Services.AddGraphQL(options =>
{
    options.AddErrorInfoProvider(o => o.ExposeExceptionDetails = builder.Environment.IsDevelopment());
    options.AddSchema<MovieReviewSchema>();
    options.AddGraphTypes(Assembly.GetExecutingAssembly());
    options.AddDataLoader();
    options.AddSystemTextJson();
});
//builder.Services.AddApplicationInsightsTelemetry(new Microsoft.ApplicationInsights.AspNetCore.Extensions.ApplicationInsightsServiceOptions
//{
//    ConnectionString = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]
//});
// application insights
builder.Services.AddApplicationInsightsTelemetry(options =>
{
    options.ConnectionString = builder.Configuration["ApplicationInsights:ConnectionString"];
});
builder.Services.AddApplicationInsightsTelemetry(builder.Configuration["ApplicationInsights:InstrumentationKey"]);



var app = builder.Build();

// Configure the HTTP request pipeline.
if (true)//app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.UseGraphQL();
app.UseGraphQLPlayground("/ui/playground");

app.MapControllers();

app.Run();