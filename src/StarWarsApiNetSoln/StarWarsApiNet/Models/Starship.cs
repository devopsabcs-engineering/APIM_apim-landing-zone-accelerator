using System;
using System.Collections.Generic;

namespace StarWarsApiNet.Models
{
    public class Starship
    {
        public int Id { get; set; }
        public string StarshipClass { get; set; }
        public string HyperdriveRating { get; set; }
        public string MGLT { get; set; }
        public List<int> Pilots { get; set; }
    }
}

