namespace OdataApp.Models
{

    using System.Collections.Generic;

    public class Customer
    {
        public int Id { get; set; }
        public required string Name { get; set; }
        public List<Order> Orders { get; set; } = [];
    }
}

