using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Graph;
using Microsoft.Identity.Web.Resource;
using Swashbuckle.AspNetCore.Annotations;

namespace Sandbox.Api.OboConnectorCore.Controllers
{
    [Authorize]
    [ApiController]
    [Produces("application/json")]
    [Route("api/[controller]")]
    [RequiredScope(new string[] { "access_as_user", "user_impersonation" })]
    public class UserController : Controller
    {
        //private IDownstreamWebApi _downstreamWebApi;
        private const string ServiceName = "DownstreamDataverseApi";
        private readonly GraphServiceClient _graphServiceClient;

        public UserController(GraphServiceClient graphServiceClient) //, IDownstreamWebApi downstreamWebApi)
        {
            _graphServiceClient = graphServiceClient;
            //_downstreamWebApi = downstreamWebApi;
        }

        //[HttpGet("users")]
        //[ProducesDefaultResponseType()]
        //[ProducesResponseType(StatusCodes.Status404NotFound)]
        //[ProducesResponseType(StatusCodes.Status200OK)]
        //[SwaggerOperation(
        //    Summary = "Get users",
        //    Description = "Get list of licensed users",
        //    OperationId = "GetUsers"
        //)]
        //public async Task<IEnumerable<Entities.User>> GetUsers()
        //{
        //    var users = new List<Entities.User>();

        //    var response = await _downstreamWebApi.CallWebApiForUserAsync(
        //        ServiceName,
        //        options =>
        //        {
        //            //https://org50078be4.api.crm.dynamics.com/api/data/v9.2
        //            var downstreamOptions = (DownstreamWebApiOptions)options;
        //            downstreamOptions.RelativePath = $"/api/data/v9.2/systemusers?$select=systemuserid,fullname,domainname,title,azureactivedirectoryobjectid&$filter=isdisabled eq false and islicensed eq true";
        //            downstreamOptions.HttpMethod = HttpMethod.Get;
        //        });

        //    if (response.StatusCode == System.Net.HttpStatusCode.OK)
        //    {
        //        var content = await response.Content.ReadAsStringAsync();
        //        dynamic responseObject = JsonConvert.DeserializeObject(content);
        //        foreach (var value in responseObject.value)
        //        {
        //            users.Add(new Entities.User
        //            {
        //                Id = value.systemuserid,
        //                FullName = value.fullname,
        //                DomainName = value.domainname,
        //                Title = value.title,
        //                AzureActiveDirectoryObjectId = value.azureactivedirectoryobjectid
        //            });
        //        }
        //    }
        //    return users;
        //}

        [HttpGet("users/{userId}/licenses")]
        [ProducesDefaultResponseType()]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [SwaggerOperation(
            Summary = "Get user licenses",
            Description = "Get user licenses",
            OperationId = "GetUserLicenses"
        )]
        public async Task<IEnumerable<Entities.License>> GetUserLicenses(string userId)
        {
            var licenseDetailsCollection = await _graphServiceClient.Users[userId].LicenseDetails.Request().GetAsync();
            var licenses = new List<Entities.License>();
            while (licenseDetailsCollection.Count > 0)
            {
                foreach (var licenseDetails in licenseDetailsCollection)
                {
                    licenses.Add(new Entities.License
                    {
                        SkuId = licenseDetails.SkuId,
                        SkuPartNumber = licenseDetails.SkuPartNumber
                    });
                }

                if (licenseDetailsCollection.NextPageRequest != null)
                {
                    licenseDetailsCollection = await licenseDetailsCollection.NextPageRequest.GetAsync();
                }
                else
                {
                    break;
                }
            }

            return licenses;
        }
    }

    //internal class DownstreamWebApiOptions
    //{
    //    public string RelativePath { get; internal set; }
    //    public HttpMethod HttpMethod { get; internal set; }
    //}

    //internal interface IDownstreamWebApi
    //{
    //    Task CallWebApiForUserAsync(string serviceName, Action<object> value);
    //}
}
