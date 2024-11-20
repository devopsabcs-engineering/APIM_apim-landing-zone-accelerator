using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.OData.Deltas;
using Microsoft.AspNetCore.OData.Routing.Controllers;
using OdataApp.Models;
using System.Reflection;

namespace OdataApp.Controllers
{
    public class ProductsController : ODataController
    {
        private AppDbContext _dbContext;
        private readonly ILogger<ProductsController> _logger;
        private readonly Version? _version;

        public ProductsController(AppDbContext dbContext, ILogger<ProductsController> logger)
        {
            _dbContext = dbContext;
            _logger = logger;
            _version = Assembly.GetExecutingAssembly().GetName().Version;
            _logger.LogInformation("ProductsController version {version}", _version);
        }

        public IActionResult Get()
        {
            // Log the version
            _logger.LogInformation($"Getting products version {_version}");
            return Ok(_dbContext.Products);
        }

        public IActionResult Get(int key)
        {
            _logger.LogInformation($"Getting product {key} (version {_version})", key);
            return Ok(_dbContext.Products.Find(key));
        }

        public async Task<IActionResult> Post([FromBody] Product product)
        {
            _logger.LogInformation($"Creating product {product.Id} (version {_version})", product.Id);
            _dbContext.Products.Add(product);
            await _dbContext.SaveChangesAsync();
            return Ok(product);
        }

        public async Task<IActionResult> Update(int key, [FromBody] Delta<Product> delta)
        {
            _logger.LogInformation($"Updating product {key} (version {_version})", key);
            var product = await _dbContext.Products.FindAsync(key);
            delta.Patch(product);
            _dbContext.Products.Update(product);
            await _dbContext.SaveChangesAsync();
            return Ok(product);
        }

        public async Task<IActionResult> Delete(int key)
        {
            _logger.LogInformation($"Deleting product {key} (version {_version})", key);
            var product = await _dbContext.Products.FindAsync(key);
            _dbContext.Products.Remove(product);
            await _dbContext.SaveChangesAsync();
            return Ok(product);
        }
    }
}
