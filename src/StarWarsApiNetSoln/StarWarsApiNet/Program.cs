using Microsoft.EntityFrameworkCore;
using StarWarsApiNet.Data;
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

            var app = builder.Build();

            // Seed the database
            SeedDatabase(app);

            // Configure the HTTP request pipeline.
            if (true)//app.Environment.IsDevelopment())
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
                var peopleData = JsonSerializer.Deserialize<List<PeopleJsonModel>>(peopleJson);
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
                var planetsData = JsonSerializer.Deserialize<List<PlanetsJsonModel>>(planetsJson);
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
                var starshipsData = JsonSerializer.Deserialize<List<StarshipsJsonModel>>(starshipsJson);
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

    public class PeopleJsonModel
    {
        public int pk { get; set; }
        public PeopleFields fields { get; set; }
    }

    public class PeopleFields
    {
        public DateTime edited { get; set; }
        public string name { get; set; }
        public DateTime created { get; set; }
        public string gender { get; set; }
        public string skin_color { get; set; }
        public string hair_color { get; set; }
        public string height { get; set; }
        public string eye_color { get; set; }
        public string mass { get; set; }
        public int homeworld { get; set; }
        public string birth_year { get; set; }
    }
    public class PlanetsJsonModel
    {
        public int pk { get; set; }
        public PlanetsFields fields { get; set; }
    }

    public class PlanetsFields
    {
        public DateTime edited { get; set; }
        public string name { get; set; }
        public DateTime created { get; set; }
        public string diameter { get; set; }
        public string rotation_period { get; set; }
        public string orbital_period { get; set; }
        public string gravity { get; set; }
        public string population { get; set; }
        public string climate { get; set; }
        public string terrain { get; set; }
        public string surface_water { get; set; }
    }
    public class SpeciesJsonModel
    {
        public int pk { get; set; }
        public SpeciesFields fields { get; set; }
    }

    public class SpeciesFields
    {
        public DateTime edited { get; set; }
        public string name { get; set; }
        public DateTime created { get; set; }
        public string classification { get; set; }
        public string designation { get; set; }
        public string average_height { get; set; }
        public string skin_colors { get; set; }
        public string hair_colors { get; set; }
        public string eye_colors { get; set; }
        public string average_lifespan { get; set; }
        public string language { get; set; }
        public int? homeworld { get; set; }
        public List<int> people { get; set; }
    }
    
    public class StarshipsJsonModel
    {
        public int pk { get; set; }
        public StarshipsFields fields { get; set; }
    }

    public class StarshipsFields
    {        
        public string hyperdrive_rating { get; set; }
        public string MGLT { get; set; }
        public string starship_class { get; set; }
        public List<int> pilots { get; set; }
    }
    public class FilmJsonModel
    {
        public int pk { get; set; }
        public FilmFields fields { get; set; }
    }

    public class FilmFields
    {
        public string title { get; set; }
        public int episode_id { get; set; }
        public string opening_crawl { get; set; }
        public string director { get; set; }
        public string producer { get; set; }
        public DateTime release_date { get; set; }
        public DateTime created { get; set; }
        public DateTime edited { get; set; }
        public List<int> characters { get; set; } // Add this line
        public List<int> planets { get; set; } // Add this line
        public List<int> starships { get; set; } // Add this line
        public List<int> vehicles { get; set; } // Add this line
        public List<int> species { get; set; } // Add this line
    }
    public class TransportJsonModel
    {
        public int pk { get; set; }
        public TransportFields fields { get; set; }
    }

    public class TransportFields
    {
        public string name { get; set; }
        public string model { get; set; }
        public string manufacturer { get; set; }
        public string cost_in_credits { get; set; }
        public string length { get; set; }
        public string max_atmosphering_speed { get; set; }
        public string crew { get; set; }
        public string passengers { get; set; }
        public string cargo_capacity { get; set; }
        public string consumables { get; set; }
        public DateTime created { get; set; }
        public DateTime edited { get; set; }
    }
    public class VehicleJsonModel
    {
        public int pk { get; set; }
        public VehicleFields fields { get; set; }
    }

    public class VehicleFields
    {
        public string vehicle_class { get; set; }
        public List<int> pilots { get; set; }
    }
}

