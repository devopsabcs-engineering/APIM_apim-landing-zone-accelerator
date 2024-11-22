using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StarWarsApiNet.Data;
using StarWarsApiNet.Models;
using System.Reflection;

namespace StarWarsApiNet.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PeopleController : ControllerBase
    {
        private readonly StarWarsContext _context;
        private readonly ILogger<PeopleController> _logger;

        public PeopleController(StarWarsContext context, ILogger<PeopleController> logger)
        {
            _context = context;
            _logger = logger;
            // get version from Assembly
            var version = Assembly.GetExecutingAssembly().GetName().Version;
            _logger.LogInformation("PeopleController version {Version}", version);
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Person>>> GetPeople([FromQuery] string search = null)
        {
            _logger.LogInformation("Getting all people");

            if (!string.IsNullOrEmpty(search))
            {
                _logger.LogInformation("Searching for people with name containing {Search}", search);
                return await _context.People
                    .Where(p => p.Name.Contains(search))
                    .ToListAsync();
            }

            return await _context.People.ToListAsync();
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<Person>> GetPerson(int id)
        {
            _logger.LogInformation("Getting person with ID {Id}", id);
            var person = await _context.People.FindAsync(id);

            if (person == null)
            {
                _logger.LogWarning("Person with ID {Id} not found", id);
                return NotFound();
            }

            return person;
        }

        [HttpPost]
        public async Task<ActionResult<Person>> PostPerson(Person person)
        {
            _logger.LogInformation("Creating a new person");
            _context.People.Add(person);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Person created with ID {Id}", person.Id);
            return CreatedAtAction(nameof(GetPerson), new { id = person.Id }, person);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> PutPerson(int id, Person person)
        {
            if (id != person.Id)
            {
                _logger.LogWarning("Person ID mismatch: {Id} != {PersonId}", id, person.Id);
                return BadRequest();
            }

            _logger.LogInformation("Updating person with ID {Id}", id);
            _context.Entry(person).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!PersonExists(id))
                {
                    _logger.LogWarning("Person with ID {Id} not found during update", id);
                    return NotFound();
                }
                else
                {
                    _logger.LogError("Concurrency exception occurred while updating person with ID {Id}", id);
                    throw;
                }
            }

            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeletePerson(int id)
        {
            _logger.LogInformation("Deleting person with ID {Id}", id);
            var person = await _context.People.FindAsync(id);
            if (person == null)
            {
                _logger.LogWarning("Person with ID {Id} not found", id);
                return NotFound();
            }

            _context.People.Remove(person);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Person with ID {Id} deleted", id);
            return NoContent();
        }

        private bool PersonExists(int id)
        {
            return _context.People.Any(e => e.Id == id);
        }
    }
}
