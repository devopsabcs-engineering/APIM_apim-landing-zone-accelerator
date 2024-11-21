using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StarWarsApiNet.Data;
using StarWarsApiNet.Models;

namespace StarWarsApiNet.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PlanetsController : ControllerBase
    {
        private readonly StarWarsContext _context;
        private readonly ILogger<PlanetsController> _logger;

        public PlanetsController(StarWarsContext context, ILogger<PlanetsController> logger)
        {
            _context = context;
            _logger = logger;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Planet>>> GetPlanets()
        {
            _logger.LogInformation("Getting all planets");
            return await _context.Planets.ToListAsync();
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<Planet>> GetPlanet(int id)
        {
            _logger.LogInformation("Getting planet with ID {Id}", id);
            var planet = await _context.Planets.FindAsync(id);

            if (planet == null)
            {
                _logger.LogWarning("Planet with ID {Id} not found", id);
                return NotFound();
            }

            return planet;
        }

        [HttpPost]
        public async Task<ActionResult<Planet>> PostPlanet(Planet planet)
        {
            _logger.LogInformation("Creating a new planet");
            _context.Planets.Add(planet);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Planet created with ID {Id}", planet.Id);
            return CreatedAtAction(nameof(GetPlanet), new { id = planet.Id }, planet);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> PutPlanet(int id, Planet planet)
        {
            if (id != planet.Id)
            {
                _logger.LogWarning("Planet ID mismatch: {Id} != {PlanetId}", id, planet.Id);
                return BadRequest();
            }

            _logger.LogInformation("Updating planet with ID {Id}", id);
            _context.Entry(planet).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!PlanetExists(id))
                {
                    _logger.LogWarning("Planet with ID {Id} not found during update", id);
                    return NotFound();
                }
                else
                {
                    _logger.LogError("Concurrency exception occurred while updating planet with ID {Id}", id);
                    throw;
                }
            }

            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeletePlanet(int id)
        {
            _logger.LogInformation("Deleting planet with ID {Id}", id);
            var planet = await _context.Planets.FindAsync(id);
            if (planet == null)
            {
                _logger.LogWarning("Planet with ID {Id} not found", id);
                return NotFound();
            }

            _context.Planets.Remove(planet);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Planet with ID {Id} deleted", id);
            return NoContent();
        }

        private bool PlanetExists(int id)
        {
            return _context.Planets.Any(e => e.Id == id);
        }
    }
}
