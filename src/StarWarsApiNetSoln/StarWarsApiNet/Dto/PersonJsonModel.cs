namespace StarWarsApiNet.Dto
{
    public class PersonJsonModel
    {
        public int pk { get; set; }
        public PersonFields fields { get; set; }
    }

    public class PersonFields
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
}
