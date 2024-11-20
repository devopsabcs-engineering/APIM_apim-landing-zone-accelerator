using System;
using System.Collections.Generic;

namespace StarWarsApiNet.Models
{
    public class Species
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Classification { get; set; }
        public string Designation { get; set; }
        public string AverageHeight { get; set; }
        public string SkinColors { get; set; }
        public string HairColors { get; set; }
        public string EyeColors { get; set; }
        public string AverageLifespan { get; set; }
        public int? Homeworld { get; set; }
        public string Language { get; set; }
        public List<int> People { get; set; }
        public DateTime Created { get; set; }
        public DateTime Edited { get; set; }
    }
}
