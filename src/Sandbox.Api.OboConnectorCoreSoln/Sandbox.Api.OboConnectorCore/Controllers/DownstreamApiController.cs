using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.Resource;
using Newtonsoft.Json;
using Sandbox.Api.OboConnectorCore.Entities;
using Swashbuckle.AspNetCore.Annotations;

namespace Sandbox.Api.OboConnectorCore.Controllers
{
    [Authorize]
    [ApiController]
    [Produces("application/json")]
    [Route("api/[controller]")]
    [RequiredScope("user_impersonation")]
    public class DownstreamApiController : Controller
    {
        private IDownstreamWebApi _downstreamWebApi;
        private const string ServiceName = "DownstreamDataverseApi";

        public DownstreamApiController(IDownstreamWebApi downstreamWebApi)
        {
            _downstreamWebApi = downstreamWebApi;
        }

        [HttpGet("accounts")]
        [ProducesDefaultResponseType()]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [SwaggerOperation(
            Summary = "Get accounts (IDownstreamWebAPI)",
            Description = "Get list of accounts using IDownstreamWebAPI",
            OperationId = "GetAccountsIDownstreamWebAPI"
        )]
        public async Task<IEnumerable<Account>> Get()
        {
            var accounts = new List<Account>();

            var response = await _downstreamWebApi.CallWebApiForUserAsync(
                ServiceName,
                options =>
                {
                    var downstreamOptions = (DownstreamWebApiOptions)options;
                    downstreamOptions.RelativePath = "/api/data/v9.2/accounts?$select=accountid,name";
                    downstreamOptions.HttpMethod = HttpMethod.Get;
                });

            if (response.StatusCode == System.Net.HttpStatusCode.OK)
            {
                var content = await response.Content.ReadAsStringAsync();
                dynamic responseObject = JsonConvert.DeserializeObject(content);
                foreach (var value in responseObject.value)
                {
                    accounts.Add(new Account { Id = value.accountid, Name = value.name });
                }
            }
            return accounts;
        }
    }
}
