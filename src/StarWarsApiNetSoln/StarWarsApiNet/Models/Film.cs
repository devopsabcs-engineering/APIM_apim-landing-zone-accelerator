using System;
using System.Collections.Generic;

namespace StarWarsApiNet.Models
{
    public class Film
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public int EpisodeId { get; set; }
        public string OpeningCrawl { get; set; }
        public string Director { get; set; }
        public string Producer { get; set; }
        public DateTime ReleaseDate { get; set; }
        public DateTime Created { get; set; }
        public DateTime Edited { get; set; }
        public List<int> Characters { get; set; }
        public List<int> Planets { get; set; }
        public List<int> Starships { get; set; }
        public List<int> Vehicles { get; set; }
        public List<int> Species { get; set; }
    }
}
