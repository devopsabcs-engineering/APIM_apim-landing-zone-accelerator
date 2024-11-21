using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StarWarsApiNet.Data;
using StarWarsApiNet.Models;

namespace StarWarsApiNet.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class SpeciesController : ControllerBase
    {
        private readonly StarWarsContext _context;
        private readonly ILogger<SpeciesController> _logger;

        public SpeciesController(StarWarsContext context, ILogger<SpeciesController> logger)
        {
            _context = context;
            _logger = logger;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Species>>> GetSpecies()
        {
            _logger.LogInformation("Getting all species");
            return await _context.Species.ToListAsync();
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<Species>> GetSpecies(int id)
        {
            _logger.LogInformation("Getting species with ID {Id}", id);
            var species = await _context.Species.FindAsync(id);

            if (species == null)
            {
                _logger.LogWarning("Species with ID {Id} not found", id);
                return NotFound();
            }

            return species;
        }

        [HttpPost]
        public async Task<ActionResult<Species>> PostSpecies(Species species)
        {
            _logger.LogInformation("Creating a new species");
            _context.Species.Add(species);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Species created with ID {Id}", species.Id);
            return CreatedAtAction(nameof(GetSpecies), new { id = species.Id }, species);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> PutSpecies(int id, Species species)
        {
            if (id != species.Id)
            {
                _logger.LogWarning("Species ID mismatch: {Id} != {SpeciesId}", id, species.Id);
                return BadRequest();
            }

            _logger.LogInformation("Updating species with ID {Id}", id);
            _context.Entry(species).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!SpeciesExists(id))
                {
                    _logger.LogWarning("Species with ID {Id} not found during update", id);
                    return NotFound();
                }
                else
                {
                    _logger.LogError("Concurrency exception occurred while updating species with ID {Id}", id);
                    throw;
                }
            }

            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteSpecies(int id)
        {
            _logger.LogInformation("Deleting species with ID {Id}", id);
            var species = await _context.Species.FindAsync(id);
            if (species == null)
            {
                _logger.LogWarning("Species with ID {Id} not found", id);
                return NotFound();
            }

            _context.Species.Remove(species);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Species with ID {Id} deleted", id);
            return NoContent();
        }

        private bool SpeciesExists(int id)
        {
            return _context.Species.Any(e => e.Id == id);
        }
    }
}
