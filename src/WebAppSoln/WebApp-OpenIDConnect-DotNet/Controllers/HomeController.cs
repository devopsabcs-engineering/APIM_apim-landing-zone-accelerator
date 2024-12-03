using Azure.Storage.Blobs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Identity.Client;
using Microsoft.Identity.Web;
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using WebApp_OpenIDConnect_DotNet.Models;
using WebApp_OpenIDConnect_DotNet.Services.Arm;
using WebApp_OpenIDConnect_DotNet.Services.GraphOperations;

namespace WebApp_OpenIDConnect_DotNet.Controllers
{
    [Authorize]
    public class HomeController : Controller
    {
        readonly ITokenAcquisition tokenAcquisition;
        private readonly IGraphApiOperations graphApiOperations;
        private readonly IArmOperations armOperations;
        private readonly IArmOperationsWithImplicitAuth armOperationsWithImplicitAuth;
        private readonly ILogger<HomeController> logger;
        private readonly IConfiguration configuration;
        private readonly string _version;

        public HomeController(ITokenAcquisition tokenAcquisition,
                              IGraphApiOperations graphApiOperations,
                              IArmOperations armOperations,
                              IArmOperationsWithImplicitAuth armOperationsWithImplicitAuth,
                              ILogger<HomeController> logger,
                              IConfiguration configuration)
        {
            this.tokenAcquisition = tokenAcquisition;
            this.graphApiOperations = graphApiOperations;
            this.armOperations = armOperations;
            this.armOperationsWithImplicitAuth = armOperationsWithImplicitAuth;
            this.logger = logger;
            this.configuration = configuration;
            // get version from the assembly
            _version = Assembly.GetExecutingAssembly().GetName().Version.ToString();
            // log the version
            logger.LogInformation($"Version: {_version}");
        }

        public IActionResult Index()
        {
            logger.LogInformation($"Index action called by {User.Identity.Name}. Version: {_version}");
            return View();
        }

        [AuthorizeForScopes(Scopes = new[] { WebApp_OpenIDConnect_DotNet.Infrastructure.Constants.ScopeUserRead })]
        public async Task<IActionResult> Profile()
        {
            logger.LogInformation($"Profile action called by {User.Identity.Name}. Version: {_version}");
            try
            {
                var accessToken = await tokenAcquisition.GetAccessTokenForUserAsync(new[] { WebApp_OpenIDConnect_DotNet.Infrastructure.Constants.ScopeUserRead });
                logger.LogInformation($"Access token: {accessToken}");
                var me = await graphApiOperations.GetUserInformation(accessToken);
                var photo = await graphApiOperations.GetPhotoAsBase64Async(accessToken);

                ViewData["Me"] = me;
                ViewData["Photo"] = photo;

                logger.LogInformation($"Profile data retrieved successfully by {User.Identity.Name}. Version: {_version}");
            }
            catch (Exception ex)
            {
                logger.LogError(ex, $"Error retrieving profile data by {User.Identity.Name}. Version: {_version}");
                throw;
            }

            return View();
        }

        [AuthorizeForScopes(Scopes = new[] { "https://management.core.windows.net/user_impersonation", "user.read", "directory.read.all" })]
        public async Task<IActionResult> Tenants()
        {
            logger.LogInformation($"Tenants action called by {User.Identity.Name}. Version: {_version}");
            try
            {
                var accessToken = await tokenAcquisition.GetAccessTokenForUserAsync(new[] { $"{ArmApiOperationService.ArmResource}user_impersonation" });
                logger.LogInformation($"Access token: {accessToken}");
                var tenantIds = await armOperations.EnumerateTenantsIdsAccessibleByUser(accessToken);

                ViewData["tenants"] = tenantIds;

                logger.LogInformation($"Tenant IDs retrieved successfully by {User.Identity.Name}. Version: {_version}");
            }
            catch (Exception ex)
            {
                logger.LogError(ex, $"Error retrieving tenant IDs by {User.Identity.Name}. Version: {_version}");
                throw;
            }

            return View();
        }

        [AuthorizeForScopes(Scopes = new[] { "https://management.core.windows.net/user_impersonation" })]
        public async Task<IActionResult> TenantsWithImplicitAuth()
        {
            logger.LogInformation($"TenantsWithImplicitAuth action called by {User.Identity.Name}. Version: {_version}");
            try
            {
                var tenantIds = await armOperationsWithImplicitAuth.EnumerateTenantsIds();

                ViewData["tenants"] = tenantIds;

                logger.LogInformation($"Tenant IDs with implicit auth retrieved successfully by {User.Identity.Name}. Version: {_version}");
            }
            catch (Exception ex)
            {
                logger.LogError(ex, $"Error retrieving tenant IDs with implicit auth by {User.Identity.Name}. Version: {_version}");
                throw;
            }

            return View(nameof(Tenants));
        }

        [AuthorizeForScopes(Scopes = new[] { "https://storage.azure.com/user_impersonation" })]
        public async Task<IActionResult> Blob()
        {
            logger.LogInformation($"Blob action called by {User.Identity.Name}. Version: {_version}");
            string message = "Blob failed to create";
            var blobFileSuffixDateTime = DateTime.Now.ToString("yyyyMMddHHmmss");
            string baseUrl = configuration["AzureStorage:BaseUrl"];
            string containerName = configuration["AzureStorage:ContainerName"];
            Uri blobUri = new Uri($"{baseUrl}/{containerName}/Blob_{blobFileSuffixDateTime}.txt");
            BlobClient blobClient = new BlobClient(blobUri, new TokenAcquisitionTokenCredential(tokenAcquisition));

            // add the user information to the blob
            string blobContents = $"User: {User.Identity.Name} created this blob at {DateTime.Now}";
            byte[] byteArray = Encoding.ASCII.GetBytes(blobContents);
            using (MemoryStream stream = new MemoryStream(byteArray))
            {
                try
                {
                    await blobClient.UploadAsync(stream);
                    message = "Blob successfully created";
                    logger.LogInformation($"Blob created successfully by {User.Identity.Name}. Version: {_version}");
                }
                catch (MicrosoftIdentityWebChallengeUserException ex)
                {
                    logger.LogError(ex, $"MicrosoftIdentityWebChallengeUserException occurred while creating blob by {User.Identity.Name}. Version: {_version}");
                    throw;
                }
                catch (MsalUiRequiredException ex)
                {
                    logger.LogError(ex, $"MsalUiRequiredException occurred while creating blob by {User.Identity.Name}. Version: {_version}");
                    throw;
                }
                catch (Exception ex)
                {
                    try
                    {
                        message += $". Reason - {((Azure.RequestFailedException)ex).ErrorCode}";
                        logger.LogError(ex, $"RequestFailedException occurred while creating blob by {User.Identity.Name}. Version: {_version}");
                    }
                    catch (Exception innerEx)
                    {
                        message += $". Reason - {ex.Message}";
                        logger.LogError(innerEx, $"Exception occurred while creating blob by {User.Identity.Name}. Version: {_version}");
                    }
                }
            }

            ViewData["Message"] = message;
            return View();
        }

        [AllowAnonymous]
        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            logger.LogError($"Error action called. Version: {_version}");
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}
