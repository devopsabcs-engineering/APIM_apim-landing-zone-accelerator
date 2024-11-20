namespace OdataApp.Models
{
    public class Order
    {
        public int Id { get; set; }
        public decimal Amount { get; set; }
        public List<Product> Products { get; set; } = [];
    }
}
