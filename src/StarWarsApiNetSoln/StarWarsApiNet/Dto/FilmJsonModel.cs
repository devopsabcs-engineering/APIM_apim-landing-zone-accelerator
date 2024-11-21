namespace StarWarsApiNet.Dto
{
    public class FilmJsonModel
    {
        public int pk { get; set; }
        public FilmFields fields { get; set; }
    }

    public class FilmFields
    {
        public string title { get; set; }
        public int episode_id { get; set; }
        public string opening_crawl { get; set; }
        public string director { get; set; }
        public string producer { get; set; }
        public DateTime release_date { get; set; }
        public DateTime created { get; set; }
        public DateTime edited { get; set; }
        public List<int> characters { get; set; } // Add this line
        public List<int> planets { get; set; } // Add this line
        public List<int> starships { get; set; } // Add this line
        public List<int> vehicles { get; set; } // Add this line
        public List<int> species { get; set; } // Add this line
    }
}
