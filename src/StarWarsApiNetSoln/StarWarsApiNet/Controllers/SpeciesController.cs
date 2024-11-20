using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StarWarsApiNet.Data;
using StarWarsApiNet.Models;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace StarWarsApiNet.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class SpeciesController : ControllerBase
    {
        private readonly StarWarsContext _context;

        public SpeciesController(StarWarsContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Species>>> GetSpecies()
        {
            return await _context.Species.ToListAsync();
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<Species>> GetSpecies(int id)
        {
            var species = await _context.Species.FindAsync(id);

            if (species == null)
            {
                return NotFound();
            }

            return species;
        }

        [HttpPost]
        public async Task<ActionResult<Species>> PostSpecies(Species species)
        {
            _context.Species.Add(species);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetSpecies), new { id = species.Id }, species);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> PutSpecies(int id, Species species)
        {
            if (id != species.Id)
            {
                return BadRequest();
            }

            _context.Entry(species).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!SpeciesExists(id))
                {
                    return NotFound();
                }
                else
                {
                    throw;
                }
            }

            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteSpecies(int id)
        {
            var species = await _context.Species.FindAsync(id);
            if (species == null)
            {
                return NotFound();
            }

            _context.Species.Remove(species);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        private bool SpeciesExists(int id)
        {
            return _context.Species.Any(e => e.Id == id);
        }
    }
}
