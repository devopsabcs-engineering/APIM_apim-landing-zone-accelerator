using Microsoft.EntityFrameworkCore;
using StarWarsApiNet.Data;
using StarWarsApiNet.Dto;
using StarWarsApiNet.Models;
using System.Text.Json;

namespace StarWarsApiNet
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            // Add services to the container.
            builder.Services.AddDbContext<StarWarsContext>(options =>
                options.UseInMemoryDatabase("StarWarsDatabase"));

            builder.Services.AddControllers();
            // Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
            builder.Services.AddEndpointsApiExplorer();
            builder.Services.AddSwaggerGen();

            // Add Application Insights telemetry
            builder.Services.AddApplicationInsightsTelemetry();

            // app insights from connection string
            builder.Services.AddApplicationInsightsTelemetry(builder.Configuration["ApplicationInsights:ConnectionString"]);

            var app = builder.Build();

            // Seed the database
            SeedDatabase(app);

            // Configure the HTTP request pipeline.
            if (true) //app.Environment.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
                app.UseSwagger();
                app.UseSwaggerUI();
            }

            app.UseHttpsRedirection();

            app.UseAuthorization();

            app.MapControllers();

            app.Run();
        }

        private static void SeedDatabase(WebApplication app)
        {
            using (var scope = app.Services.CreateScope())
            {
                var context = scope.ServiceProvider.GetRequiredService<StarWarsContext>();

                // Seed People
                var peopleJson = File.ReadAllText("resources/fixtures/people.json");
                var peopleData = JsonSerializer.Deserialize<List<PersonJsonModel>>(peopleJson);
                var people = peopleData.Select(p => new Person
                {
                    Id = p.pk,
                    Name = p.fields.name,
                    Gender = p.fields.gender,
                    SkinColor = p.fields.skin_color,
                    HairColor = p.fields.hair_color,
                    Height = p.fields.height,
                    EyeColor = p.fields.eye_color,
                    Mass = p.fields.mass,
                    Homeworld = p.fields.homeworld,
                    BirthYear = p.fields.birth_year,
                    Created = p.fields.created,
                    Edited = p.fields.edited
                }).ToList();
                context.People.AddRange(people);

                // Seed Planets
                var planetsJson = File.ReadAllText("resources/fixtures/planets.json");
                var planetsData = JsonSerializer.Deserialize<List<PlanetJsonModel>>(planetsJson);
                var planets = planetsData.Select(p => new Planet
                {
                    Id = p.pk,
                    Name = p.fields.name,
                    Diameter = p.fields.diameter,
                    RotationPeriod = p.fields.rotation_period,
                    OrbitalPeriod = p.fields.orbital_period,
                    Gravity = p.fields.gravity,
                    Population = p.fields.population,
                    Climate = p.fields.climate,
                    Terrain = p.fields.terrain,
                    SurfaceWater = p.fields.surface_water,
                    Created = p.fields.created,
                    Edited = p.fields.edited
                }).ToList();
                context.Planets.AddRange(planets);

                // Seed Species
                var speciesJson = File.ReadAllText("resources/fixtures/species.json");
                var speciesData = JsonSerializer.Deserialize<List<SpeciesJsonModel>>(speciesJson);
                var species = speciesData.Select(s => new Species
                {
                    Id = s.pk,
                    Name = s.fields.name,
                    Classification = s.fields.classification,
                    Designation = s.fields.designation,
                    AverageHeight = s.fields.average_height,
                    SkinColors = s.fields.skin_colors,
                    HairColors = s.fields.hair_colors,
                    EyeColors = s.fields.eye_colors,
                    AverageLifespan = s.fields.average_lifespan,
                    Language = s.fields.language,
                    Homeworld = s.fields.homeworld,
                    Created = s.fields.created,
                    Edited = s.fields.edited,
                    People = s.fields.people
                }).ToList();
                context.Species.AddRange(species);

                // Seed Starships
                var starshipsJson = File.ReadAllText("resources/fixtures/starships.json");
                var starshipsData = JsonSerializer.Deserialize<List<StarshipJsonModel>>(starshipsJson);
                var starships = starshipsData.Select(s => new Starship
                {
                    Id = s.pk,
                    HyperdriveRating = s.fields.hyperdrive_rating,
                    MGLT = s.fields.MGLT,
                    StarshipClass = s.fields.starship_class,
                    Pilots = s.fields.pilots
                }).ToList();
                context.Starships.AddRange(starships);

                // Seed Transport
                var transportJson = File.ReadAllText("resources/fixtures/transport.json");
                var transportData = JsonSerializer.Deserialize<List<TransportJsonModel>>(transportJson);
                var transport = transportData.Select(t => new Transport
                {
                    Id = t.pk,
                    Name = t.fields.name,
                    Model = t.fields.model,
                    Manufacturer = t.fields.manufacturer,
                    CostInCredits = t.fields.cost_in_credits,
                    Length = t.fields.length,
                    MaxAtmospheringSpeed = t.fields.max_atmosphering_speed,
                    Crew = t.fields.crew,
                    Passengers = t.fields.passengers,
                    CargoCapacity = t.fields.cargo_capacity,
                    Consumables = t.fields.consumables,
                    Created = t.fields.created,
                    Edited = t.fields.edited
                }).ToList();
                context.Transports.AddRange(transport);

                // Seed Films
                var filmsJson = File.ReadAllText("resources/fixtures/films.json");
                var filmsData = JsonSerializer.Deserialize<List<FilmJsonModel>>(filmsJson);
                var films = filmsData.Select(f => new Film
                {
                    Id = f.pk,
                    Title = f.fields.title,
                    EpisodeId = f.fields.episode_id,
                    OpeningCrawl = f.fields.opening_crawl,
                    Director = f.fields.director,
                    Producer = f.fields.producer,
                    ReleaseDate = f.fields.release_date,
                    Created = f.fields.created,
                    Edited = f.fields.edited,
                    // add child lists
                    Characters = f.fields.characters ?? new List<int>(),
                    Planets = f.fields.planets ?? new List<int>(),
                    Starships = f.fields.starships ?? new List<int>(),
                    Vehicles = f.fields.vehicles ?? new List<int>(),
                    Species = f.fields.species ?? new List<int>()
                }).ToList();
                context.Films.AddRange(films);

                // Seed Vehicles
                var vehiclesJson = File.ReadAllText("resources/fixtures/vehicles.json");
                var vehiclesData = JsonSerializer.Deserialize<List<VehicleJsonModel>>(vehiclesJson);
                var vehicles = vehiclesData.Select(v => new Vehicle
                {
                    Id = v.pk,
                    VehicleClass = v.fields.vehicle_class,
                    Pilots = v.fields.pilots ?? new List<int>()
                }).ToList();
                context.Vehicles.AddRange(vehicles);

                context.SaveChanges();
            }
        }
    }









}

