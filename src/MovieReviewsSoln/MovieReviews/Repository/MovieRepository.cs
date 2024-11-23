using Microsoft.EntityFrameworkCore;
using MovieReviews.Database;
using MovieReviews.Models;

namespace MovieReviews.Repository
{
    public class MovieRepository : IMovieRepository
    {
        private readonly MovieContext _context;
        private readonly ILogger<MovieRepository> _logger; // Add this field

        public MovieRepository(MovieContext context, ILogger<MovieRepository> logger)
        {
            _logger = logger;
            _context = context;
            // get version from assembly
            var version = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
            _logger.LogInformation($"MovieRepository version {version}");
            _context.Database.EnsureCreated();
        }

        public async Task<List<Movie>> GetMoviesAsync()
        {
            // get version from assembly
            var version = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;

            //add custom trace log for application insights
            _logger.LogInformation("Getting movies");
            _logger.LogDebug($"Debug {version}");
            _logger.LogInformation($"Information {version}");
            _logger.LogWarning($"Warning {version}");
            _logger.LogError($"Error {version}");
            _logger.LogCritical($"Critical {version}");
            
            return await _context.Movies.AsNoTracking().ToListAsync();
        }

        public async Task<Movie> GetMovieByIdAsync(Guid id)
        {
            _logger.LogInformation($"Getting movie by id {id}");
            return await _context.Movies.Where(m => m.Id == id).AsNoTracking().FirstOrDefaultAsync();
        }

        public async Task<Movie> AddReviewToMovieAsync(Guid id, Review review)
        {
            _logger.LogInformation($"Adding review to movie with id {id}");
            var movie = await _context.Movies.Where(m => m.Id == id).FirstOrDefaultAsync();
            movie.AddReview(review);
            await _context.SaveChangesAsync();
            return movie;
        }
    }
}