using System;

namespace StarWarsApiNet.Models
{
    public class Planet
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Climate { get; set; }
        public string Terrain { get; set; }
        public string Gravity { get; set; }
        public string Diameter { get; set; } //diameter can be unknown string
        public string RotationPeriod { get; set; } //rotation_period can be unknown string
        public string OrbitalPeriod { get; set; } //orbital_period can be unknown string
        public string Population { get; set; } //population can be unknown string
        public string SurfaceWater { get; set; } //surface_water can be unknown string
        public DateTime Created { get; set; }
        public DateTime Edited { get; set; }
    }
}
