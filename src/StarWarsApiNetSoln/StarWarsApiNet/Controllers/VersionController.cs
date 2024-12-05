using Microsoft.AspNetCore.Mvc;
using System.Reflection;

namespace StarWarsApiNet.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class VersionController : ControllerBase
    {
        [HttpGet]
        public ActionResult<string> GetVersion()
        {
            var version = Assembly.GetExecutingAssembly().GetName().Version?.ToString();
            return Ok(version);
        }
    }
}
