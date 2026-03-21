using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Reflection;

namespace WebApp_OpenIDConnect_DotNet.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [AllowAnonymous]
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
