using System;
using System.Collections.Generic;

namespace StarWarsApiNet.Models
{
    public class Vehicle
    {
        public int Id { get; set; }
        public string VehicleClass { get; set; }
        public List<int> Pilots { get; set; }
    }
}

