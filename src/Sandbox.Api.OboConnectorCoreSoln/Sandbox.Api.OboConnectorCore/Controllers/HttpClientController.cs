using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.Resource;
using Sandbox.Api.OboConnectorCore.Entities;
using Swashbuckle.AspNetCore.Annotations;
using System.Net.Http.Headers;
using System.Text.Json;

namespace Sandbox.Api.OboConnectorCore.Controllers
{
    [Authorize]
    [ApiController]
    [Produces("application/json")]
    [Route("api/[controller]")]
    [RequiredScope("user_impersonation")]
    public class HttpClientController : Controller
    {
        private readonly string _instanceUrl;
        private readonly IEnumerable<string> _scopesToAccessDataverseApi;
        private readonly ITokenAcquisition _tokenAcquisition;

        public HttpClientController(ITokenAcquisition tokenAcquisition, IConfiguration configuration)
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
            Summary = "Get accounts (HttpClient)",
            Description = "Get list of accounts using HttpClient",
            OperationId = "GetAccountsHttpClient"
        )]
        public async Task<IEnumerable<Account>> Get()
        {
            var accessToken
                = await _tokenAcquisition.GetAccessTokenForUserAsync(_scopesToAccessDataverseApi);
            var accounts = new List<Account>();

            using (var httpClient = new HttpClient())
            {
                httpClient.BaseAddress = new Uri(_instanceUrl);
                httpClient.Timeout = new TimeSpan(0, 2, 0);
                httpClient.DefaultRequestHeaders.Add("OData-MaxVersion", "4.0");
                httpClient.DefaultRequestHeaders.Add("OData-Version", "4.0");
                httpClient.DefaultRequestHeaders.Accept.Add(
                    new MediaTypeWithQualityHeaderValue("application/json")
                );
                httpClient.DefaultRequestHeaders.Authorization
                    = new AuthenticationHeaderValue("Bearer", accessToken);
                var response
                    = await httpClient.GetAsync($"{_instanceUrl}/api/data/v9.2/accounts?$select=name,accountid");
                if (response.StatusCode == System.Net.HttpStatusCode.OK)
                {
                    var content = await response.Content.ReadAsStringAsync();
                    // deserialize using System.Text.Json.JsonSerializer
                    dynamic responseObject = JsonSerializer.Deserialize<dynamic>(content);
                    foreach (var value in responseObject.value)
                    {
                        accounts.Add(new Account { Id = value.accountid, Name = value.name });
                    }
                }
            }
            return accounts;
        }
    }
}
