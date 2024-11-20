using System;

namespace StarWarsApiNet.Models
{
    public class Person
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public DateTime Created { get; set; }
        public DateTime Edited { get; set; }
        public string Gender { get; set; }
        public string SkinColor { get; set; }
        public string HairColor { get; set; }
        public string Height { get; set; } //height can be unknown string
        public string EyeColor { get; set; }
        public string Mass { get; set; } //mass can be unknown string
        public int Homeworld { get; set; }
        public string BirthYear { get; set; }
    }
}
