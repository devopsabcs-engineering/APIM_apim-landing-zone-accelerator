namespace OdataApp.Controllers
{
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.AspNetCore.OData.Query;
    using Microsoft.AspNetCore.OData.Routing.Controllers;
    using OdataApp.Models;
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using System.Reflection;

    public class CustomersController : ODataController
    {
        private static readonly Random random = new();
        private static readonly List<Customer> customers = new(
            Enumerable.Range(1, 3).Select(idx => new Customer
            {
                Id = idx,
                Name = $"Customer {idx}",
                Version = Assembly.GetExecutingAssembly().GetName().Version.ToString(),
                Orders = new List<Order>(
                    Enumerable.Range(1, 2).Select(dx => new Order
                    {
                        Id = (idx - 1) * 2 + dx,
                        Amount = random.Next(1, 9) * 10
                    }))
            }));

        private readonly ILogger<CustomersController> _logger;
        private readonly Version? _version;

        public CustomersController(ILogger<CustomersController> logger)
        {
            _logger = logger;
            // get version from Executing Assembly
            _version = Assembly.GetExecutingAssembly().GetName().Version;
            _logger.LogInformation("CustomersController version {Version}", _version);
        }

        [EnableQuery]
        public ActionResult<IEnumerable<Customer>> Get()
        {
            _logger.LogInformation("Getting customers version {Version}", _version);
            return Ok(customers);
        }

        [EnableQuery]
        public ActionResult<Customer> Get([FromRoute] int key)
        {
            _logger.LogInformation("Getting customer {Key} (version {Version})", key, _version);
            var item = customers.SingleOrDefault(d => d.Id.Equals(key));

            if (item == null)
            {
                return NotFound();
            }

            return Ok(item);
        }
    }
}
