using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StarWarsApiNet.Data;
using StarWarsApiNet.Models;

namespace StarWarsApiNet.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class FilmsController : ControllerBase
    {
        private readonly StarWarsContext _context;
        private readonly ILogger<FilmsController> _logger;

        public FilmsController(StarWarsContext context, ILogger<FilmsController> logger)
        {
            _context = context;
            _logger = logger;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Film>>> GetFilms()
        {
            _logger.LogInformation("Getting all films");
            return await _context.Films.ToListAsync();
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<Film>> GetFilm(int id)
        {
            _logger.LogInformation("Getting film with ID {Id}", id);
            var film = await _context.Films.FindAsync(id);

            if (film == null)
            {
                _logger.LogWarning("Film with ID {Id} not found", id);
                return NotFound();
            }

            return film;
        }

        [HttpPost]
        public async Task<ActionResult<Film>> PostFilm(Film film)
        {
            _logger.LogInformation("Creating a new film");
            _context.Films.Add(film);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Film created with ID {Id}", film.Id);
            return CreatedAtAction(nameof(GetFilm), new { id = film.Id }, film);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> PutFilm(int id, Film film)
        {
            if (id != film.Id)
            {
                _logger.LogWarning("Film ID mismatch: {Id} != {FilmId}", id, film.Id);
                return BadRequest();
            }

            _logger.LogInformation("Updating film with ID {Id}", id);
            _context.Entry(film).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!FilmExists(id))
                {
                    _logger.LogWarning("Film with ID {Id} not found during update", id);
                    return NotFound();
                }
                else
                {
                    _logger.LogError("Concurrency exception occurred while updating film with ID {Id}", id);
                    throw;
                }
            }

            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteFilm(int id)
        {
            _logger.LogInformation("Deleting film with ID {Id}", id);
            var film = await _context.Films.FindAsync(id);
            if (film == null)
            {
                _logger.LogWarning("Film with ID {Id} not found", id);
                return NotFound();
            }

            _context.Films.Remove(film);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Film with ID {Id} deleted", id);
            return NoContent();
        }

        private bool FilmExists(int id)
        {
            return _context.Films.Any(e => e.Id == id);
        }
    }
}
