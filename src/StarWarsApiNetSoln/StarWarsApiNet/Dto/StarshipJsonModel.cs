namespace StarWarsApiNet.Dto
{
    public class StarshipJsonModel
    {
        public int pk { get; set; }
        public StarshipFields fields { get; set; }
    }

    public class StarshipFields
    {
        public string hyperdrive_rating { get; set; }
        public string MGLT { get; set; }
        public string starship_class { get; set; }
        public List<int> pilots { get; set; }
    }
}
