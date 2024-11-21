namespace StarWarsApiNet.Dto
{
    public class TransportJsonModel
    {
        public int pk { get; set; }
        public TransportFields fields { get; set; }
    }

    public class TransportFields
    {
        public string name { get; set; }
        public string model { get; set; }
        public string manufacturer { get; set; }
        public string cost_in_credits { get; set; }
        public string length { get; set; }
        public string max_atmosphering_speed { get; set; }
        public string crew { get; set; }
        public string passengers { get; set; }
        public string cargo_capacity { get; set; }
        public string consumables { get; set; }
        public DateTime created { get; set; }
        public DateTime edited { get; set; }
    }
}
