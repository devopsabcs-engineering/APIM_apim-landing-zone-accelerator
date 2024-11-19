namespace OdataApp.Controllers
{
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.AspNetCore.OData.Query;
    using Microsoft.AspNetCore.OData.Routing.Controllers;
    using OdataApp.Models;
    using System;
    using System.Collections.Generic;
    using System.Linq;

    public class CustomersController : ODataController
    {
        private static Random random = new Random();
        private static List<Customer> customers = new List<Customer>(
            Enumerable.Range(1, 3).Select(idx => new Customer
            {
                Id = idx,
                Name = $"Customer {idx}",
                Orders = new List<Order>(
                    Enumerable.Range(1, 2).Select(dx => new Order
                    {
                        Id = (idx - 1) * 2 + dx,
                        Amount = random.Next(1, 9) * 10
                    }))
            }));

        private readonly ILogger<CustomersController> _logger;

        public CustomersController(ILogger<CustomersController> logger)
        {
            _logger = logger;
        }

        [EnableQuery]
        public ActionResult<IEnumerable<Customer>> Get()
        {
            _logger.LogInformation("Getting customers");
            return Ok(customers);
        }

        [EnableQuery]
        public ActionResult<Customer> Get([FromRoute] int key)
        {
            _logger.LogInformation("Getting customer {key}", key);
            var item = customers.SingleOrDefault(d => d.Id.Equals(key));

            if (item == null)
            {
                return NotFound();
            }

            return Ok(item);
        }
    }
}
