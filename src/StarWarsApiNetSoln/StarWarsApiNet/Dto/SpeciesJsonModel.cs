namespace StarWarsApiNet.Dto
{
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
}
