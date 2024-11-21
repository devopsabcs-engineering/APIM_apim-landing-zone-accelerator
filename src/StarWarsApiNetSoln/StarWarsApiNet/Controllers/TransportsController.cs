using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StarWarsApiNet.Data;
using StarWarsApiNet.Models;
using System.Reflection;

namespace StarWarsApiNet.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class TransportsController : ControllerBase
    {
        private readonly StarWarsContext _context;
        private readonly ILogger<TransportsController> _logger;

        public TransportsController(StarWarsContext context, ILogger<TransportsController> logger)
        {
            _context = context;
            _logger = logger;
            // get version from Assembly
            var version = Assembly.GetExecutingAssembly().GetName().Version;
            _logger.LogInformation("TransportsController version {Version}", version);
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Transport>>> GetTransports()
        {
            _logger.LogInformation("Getting all transports");
            return await _context.Transports.ToListAsync();
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<Transport>> GetTransport(int id)
        {
            _logger.LogInformation("Getting transport with ID {Id}", id);
            var transport = await _context.Transports.FindAsync(id);

            if (transport == null)
            {
                _logger.LogWarning("Transport with ID {Id} not found", id);
                return NotFound();
            }

            return transport;
        }

        [HttpPost]
        public async Task<ActionResult<Transport>> PostTransport(Transport transport)
        {
            _logger.LogInformation("Creating a new transport");
            _context.Transports.Add(transport);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Transport created with ID {Id}", transport.Id);
            return CreatedAtAction(nameof(GetTransport), new { id = transport.Id }, transport);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> PutTransport(int id, Transport transport)
        {
            if (id != transport.Id)
            {
                _logger.LogWarning("Transport ID mismatch: {Id} != {TransportId}", id, transport.Id);
                return BadRequest();
            }

            _logger.LogInformation("Updating transport with ID {Id}", id);
            _context.Entry(transport).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!TransportExists(id))
                {
                    _logger.LogWarning("Transport with ID {Id} not found during update", id);
                    return NotFound();
                }
                else
                {
                    _logger.LogError("Concurrency exception occurred while updating transport with ID {Id}", id);
                    throw;
                }
            }

            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteTransport(int id)
        {
            _logger.LogInformation("Deleting transport with ID {Id}", id);
            var transport = await _context.Transports.FindAsync(id);
            if (transport == null)
            {
                _logger.LogWarning("Transport with ID {Id} not found", id);
                return NotFound();
            }

            _context.Transports.Remove(transport);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Transport with ID {Id} deleted", id);
            return NoContent();
        }

        private bool TransportExists(int id)
        {
            return _context.Transports.Any(e => e.Id == id);
        }
    }
}
