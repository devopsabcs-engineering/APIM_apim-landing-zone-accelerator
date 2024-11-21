namespace StarWarsApiNet.Dto
{
    public class PlanetJsonModel
    {
        public int pk { get; set; }
        public PlanetFields fields { get; set; }
    }

    public class PlanetFields
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
}
