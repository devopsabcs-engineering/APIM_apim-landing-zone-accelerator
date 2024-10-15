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
            _context.Database.EnsureCreated();
        }

        public async Task<List<Movie>> GetMoviesAsync()
        {            
            var iteration = 1;

            //add custom trace log for application insights
            _logger.LogInformation("Getting movies");
            _logger.LogDebug($"Debug {iteration}");
            _logger.LogInformation($"Information {iteration}");
            _logger.LogWarning($"Warning {iteration}");
            _logger.LogError($"Error {iteration}");
            _logger.LogCritical($"Critical {iteration}");
            
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