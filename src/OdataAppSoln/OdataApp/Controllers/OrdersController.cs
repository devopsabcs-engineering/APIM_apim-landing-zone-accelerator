using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.OData.Deltas;
using Microsoft.EntityFrameworkCore;
using OdataApp.Models;
using System.Reflection;

namespace OdataApp.Controllers
{
    public class OrdersController : Controller
    {
        private readonly AppDbContext _dbContext;
        private readonly ILogger<OrdersController> _logger;
        private readonly Version? _version;

        public OrdersController(AppDbContext context, ILogger<OrdersController> logger)
        {
            _dbContext = context;
            _logger = logger;
            // get version from Executing Assembly
            _version = Assembly.GetExecutingAssembly().GetName().Version;
            _logger.LogInformation("OrdersController version {version}", _version);
        }

        public IActionResult Get()
        {
            // Log the version
            _logger.LogInformation("Getting orders version {version}", _version);
            return Ok(_dbContext.Orders);
        }

        public IActionResult Get(int key)
        {
            _logger.LogInformation("Getting order {key} (version {version})", key, _version);
            return Ok(_dbContext.Orders.Find(key));
        }

        public async Task<IActionResult> Post([FromBody] Order order)
        {
            _logger.LogInformation("Creating order {orderId} (version {version})", order.Id, _version);
            _dbContext.Orders.Add(order);
            await _dbContext.SaveChangesAsync();
            return Ok(order);
        }

        public async Task<IActionResult> Update(int key, [FromBody] Delta<Order> delta)
        {
            _logger.LogInformation("Updating order {key} (version {version})", key, _version);
            var order = await _dbContext.Orders.FindAsync(key);
            delta.Patch(order);
            _dbContext.Orders.Update(order);
            await _dbContext.SaveChangesAsync();
            return Ok(order);
        }

        public async Task<IActionResult> Delete(int key)
        {
            _logger.LogInformation("Deleting order {key} (version {version})", key, _version);
            var order = await _dbContext.Orders.FindAsync(key);
            _dbContext.Orders.Remove(order);
            await _dbContext.SaveChangesAsync();
            return Ok(order);
        }

    }
}