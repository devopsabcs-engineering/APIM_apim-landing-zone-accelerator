using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.Resource;
using Microsoft.PowerPlatform.Dataverse.Client;
using Microsoft.Xrm.Sdk.Query;
using Sandbox.Api.OboConnectorCore.Entities;
using Swashbuckle.AspNetCore.Annotations;

namespace Sandbox.Api.OboConnectorCore.Controllers
{
    [Authorize]
    [ApiController]
    [Produces("application/json")]
    [Route("api/[controller]")]
    [RequiredScope("user_impersonation")]
    public class ServiceClientController : Controller
    {
        private readonly string _instanceUrl;
        private readonly IEnumerable<string> _scopesToAccessDataverseApi;
        private readonly ITokenAcquisition _tokenAcquisition;

        public ServiceClientController(ITokenAcquisition tokenAcquisition, IConfiguration configuration)
        {
            _instanceUrl = configuration["DataverseApi:BaseUrl"];
            _scopesToAccessDataverseApi
                = configuration["DataverseApi:Scopes"].Split(' ').Select(x => $"{_instanceUrl}/{x}");
            _tokenAcquisition = tokenAcquisition;
        }

        [HttpGet("accounts")]
        [ProducesDefaultResponseType()]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [SwaggerOperation(
            Summary = "Get accounts (Microsoft.PowerPlatform.Dataverse.Client)",
            Description = "Get list of accounts using Microsoft.PowerPlatform.Dataverse.Client",
            OperationId = "GetAccountsServiceClient"
        )]
        public async Task<IEnumerable<Account>> Get()
        {
            async Task<string> tokenProvider(string _)
            {
                return await _tokenAcquisition.GetAccessTokenForUserAsync(_scopesToAccessDataverseApi);
            }

            var serviceClient = new ServiceClient(new Uri(_instanceUrl), tokenProvider);

            var response = await serviceClient.RetrieveMultipleAsync(
                new Microsoft.Xrm.Sdk.Query.QueryExpression("account")
                {
                    ColumnSet = new ColumnSet("name", "accountid")
                });

            var accounts = response.Entities.Select(x => new Account { Id = x.Id, Name = x["name"] as string });
            return accounts;
        }

    }
}
