using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StarWarsApiNet.Data;
using StarWarsApiNet.Models;
using System.Reflection;

namespace StarWarsApiNet.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class VehiclesController : ControllerBase
    {
        private readonly StarWarsContext _context;
        private readonly ILogger<VehiclesController> _logger;

        public VehiclesController(StarWarsContext context, ILogger<VehiclesController> logger)
        {
            _context = context;
            _logger = logger;
            // get version from Assembly
            var version = Assembly.GetExecutingAssembly().GetName().Version;
            _logger.LogInformation("VehiclesController version {Version}", version);
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Vehicle>>> GetVehicles()
        {
            _logger.LogInformation("Getting all vehicles");
            return await _context.Vehicles.ToListAsync();
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<Vehicle>> GetVehicle(int id)
        {
            _logger.LogInformation("Getting vehicle with ID {Id}", id);
            var vehicle = await _context.Vehicles.FindAsync(id);

            if (vehicle == null)
            {
                _logger.LogWarning("Vehicle with ID {Id} not found", id);
                return NotFound();
            }

            return vehicle;
        }

        [HttpPost]
        public async Task<ActionResult<Vehicle>> PostVehicle(Vehicle vehicle)
        {
            _logger.LogInformation("Creating a new vehicle");
            _context.Vehicles.Add(vehicle);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Vehicle created with ID {Id}", vehicle.Id);
            return CreatedAtAction(nameof(GetVehicle), new { id = vehicle.Id }, vehicle);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> PutVehicle(int id, Vehicle vehicle)
        {
            if (id != vehicle.Id)
            {
                _logger.LogWarning("Vehicle ID mismatch: {Id} != {VehicleId}", id, vehicle.Id);
                return BadRequest();
            }

            _logger.LogInformation("Updating vehicle with ID {Id}", id);
            _context.Entry(vehicle).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!VehicleExists(id))
                {
                    _logger.LogWarning("Vehicle with ID {Id} not found during update", id);
                    return NotFound();
                }
                else
                {
                    _logger.LogError("Concurrency exception occurred while updating vehicle with ID {Id}", id);
                    throw;
                }
            }

            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteVehicle(int id)
        {
            _logger.LogInformation("Deleting vehicle with ID {Id}", id);
            var vehicle = await _context.Vehicles.FindAsync(id);
            if (vehicle == null)
            {
                _logger.LogWarning("Vehicle with ID {Id} not found", id);
                return NotFound();
            }

            _context.Vehicles.Remove(vehicle);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Vehicle with ID {Id} deleted", id);
            return NoContent();
        }

        private bool VehicleExists(int id)
        {
            return _context.Vehicles.Any(e => e.Id == id);
        }
    }
}
