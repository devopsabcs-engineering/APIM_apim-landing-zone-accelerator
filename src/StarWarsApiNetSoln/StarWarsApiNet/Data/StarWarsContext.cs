using Microsoft.EntityFrameworkCore;
using StarWarsApiNet.Models;

namespace StarWarsApiNet.Data
{
    public class StarWarsContext : DbContext
    {
        public StarWarsContext(DbContextOptions<StarWarsContext> options) : base(options)
        {
            // ensure the database is created
            Database.EnsureCreated();
        }

        public DbSet<Planet> Planets { get; set; }
        public DbSet<Transport> Transports { get; set; }
        public DbSet<Vehicle> Vehicles { get; set; }
        public DbSet<Starship> Starships { get; set; }
        public DbSet<Species> Species { get; set; }
        public DbSet<Person> People { get; set; }
        public DbSet<Film> Films { get; set; }


        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Additional configuration can go here
        }
    }
}
