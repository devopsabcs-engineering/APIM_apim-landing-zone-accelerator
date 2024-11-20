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
    public class PlanetsController : ControllerBase
    {
        private readonly StarWarsContext _context;

        public PlanetsController(StarWarsContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Planet>>> GetPlanets()
        {
            return await _context.Planets.ToListAsync();
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<Planet>> GetPlanet(int id)
        {
            var planet = await _context.Planets.FindAsync(id);

            if (planet == null)
            {
                return NotFound();
            }

            return planet;
        }

        [HttpPost]
        public async Task<ActionResult<Planet>> PostPlanet(Planet planet)
        {
            _context.Planets.Add(planet);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetPlanet), new { id = planet.Id }, planet);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> PutPlanet(int id, Planet planet)
        {
            if (id != planet.Id)
            {
                return BadRequest();
            }

            _context.Entry(planet).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!PlanetExists(id))
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
        public async Task<IActionResult> DeletePlanet(int id)
        {
            var planet = await _context.Planets.FindAsync(id);
            if (planet == null)
            {
                return NotFound();
            }

            _context.Planets.Remove(planet);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        private bool PlanetExists(int id)
        {
            return _context.Planets.Any(e => e.Id == id);
        }
    }
}
