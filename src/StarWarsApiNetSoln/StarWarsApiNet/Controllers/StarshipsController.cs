using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StarWarsApiNet.Data;
using StarWarsApiNet.Models;
using System.Reflection;

namespace StarWarsApiNet.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class StarshipsController : ControllerBase
    {
        private readonly StarWarsContext _context;
        private readonly ILogger<StarshipsController> _logger;

        public StarshipsController(StarWarsContext context, ILogger<StarshipsController> logger)
        {
            _context = context;
            _logger = logger;
            // get version from Assembly
            var version = Assembly.GetExecutingAssembly().GetName().Version;
            _logger.LogInformation("StarshipsController version {Version}", version);
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Starship>>> GetStarships()
        {
            _logger.LogInformation("Getting all starships");
            return await _context.Starships.ToListAsync();
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<Starship>> GetStarship(int id)
        {
            _logger.LogInformation("Getting starship with ID {Id}", id);
            var starship = await _context.Starships.FindAsync(id);

            if (starship == null)
            {
                _logger.LogWarning("Starship with ID {Id} not found", id);
                return NotFound();
            }

            return starship;
        }

        [HttpPost]
        public async Task<ActionResult<Starship>> PostStarship(Starship starship)
        {
            _logger.LogInformation("Creating a new starship");
            _context.Starships.Add(starship);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Starship created with ID {Id}", starship.Id);
            return CreatedAtAction(nameof(GetStarship), new { id = starship.Id }, starship);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> PutStarship(int id, Starship starship)
        {
            if (id != starship.Id)
            {
                _logger.LogWarning("Starship ID mismatch: {Id} != {StarshipId}", id, starship.Id);
                return BadRequest();
            }

            _logger.LogInformation("Updating starship with ID {Id}", id);
            _context.Entry(starship).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!StarshipExists(id))
                {
                    _logger.LogWarning("Starship with ID {Id} not found during update", id);
                    return NotFound();
                }
                else
                {
                    _logger.LogError("Concurrency exception occurred while updating starship with ID {Id}", id);
                    throw;
                }
            }

            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteStarship(int id)
        {
            _logger.LogInformation("Deleting starship with ID {Id}", id);
            var starship = await _context.Starships.FindAsync(id);
            if (starship == null)
            {
                _logger.LogWarning("Starship with ID {Id} not found", id);
                return NotFound();
            }

            _context.Starships.Remove(starship);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Starship with ID {Id} deleted", id);
            return NoContent();
        }

        private bool StarshipExists(int id)
        {
            return _context.Starships.Any(e => e.Id == id);
        }
    }
}
