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
    public class StarshipsController : ControllerBase
    {
        private readonly StarWarsContext _context;

        public StarshipsController(StarWarsContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Starship>>> GetStarships()
        {
            return await _context.Starships.ToListAsync();
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<Starship>> GetStarship(int id)
        {
            var starship = await _context.Starships.FindAsync(id);

            if (starship == null)
            {
                return NotFound();
            }

            return starship;
        }

        [HttpPost]
        public async Task<ActionResult<Starship>> PostStarship(Starship starship)
        {
            _context.Starships.Add(starship);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetStarship), new { id = starship.Id }, starship);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> PutStarship(int id, Starship starship)
        {
            if (id != starship.Id)
            {
                return BadRequest();
            }

            _context.Entry(starship).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!StarshipExists(id))
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
        public async Task<IActionResult> DeleteStarship(int id)
        {
            var starship = await _context.Starships.FindAsync(id);
            if (starship == null)
            {
                return NotFound();
            }

            _context.Starships.Remove(starship);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        private bool StarshipExists(int id)
        {
            return _context.Starships.Any(e => e.Id == id);
        }
    }
}
