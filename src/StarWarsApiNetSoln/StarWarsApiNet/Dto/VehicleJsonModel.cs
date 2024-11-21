namespace StarWarsApiNet.Dto
{
    public class VehicleJsonModel
    {
        public int pk { get; set; }
        public VehicleFields fields { get; set; }
    }

    public class VehicleFields
    {
        public string vehicle_class { get; set; }
        public List<int> pilots { get; set; }
    }
}
