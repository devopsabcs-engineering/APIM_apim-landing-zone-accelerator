using Azure.Storage.Blobs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Identity.Client;
using Microsoft.Identity.Web;
using System;
using System.Diagnostics;
using System.IO;
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

        public HomeController(ITokenAcquisition tokenAcquisition,
                              IGraphApiOperations graphApiOperations,
                              IArmOperations armOperations,
                              IArmOperationsWithImplicitAuth armOperationsWithImplicitAuth,
                              ILogger<HomeController> logger)
        {
            this.tokenAcquisition = tokenAcquisition;
            this.graphApiOperations = graphApiOperations;
            this.armOperations = armOperations;
            this.armOperationsWithImplicitAuth = armOperationsWithImplicitAuth;
            this.logger = logger;
        }

        public IActionResult Index()
        {
            logger.LogInformation("Index action called.");
            return View();
        }

        [AuthorizeForScopes(Scopes = new[] { WebApp_OpenIDConnect_DotNet.Infrastructure.Constants.ScopeUserRead })]
        public async Task<IActionResult> Profile()
        {
            logger.LogInformation("Profile action called.");
            try
            {
                var accessToken = await tokenAcquisition.GetAccessTokenForUserAsync(new[] { WebApp_OpenIDConnect_DotNet.Infrastructure.Constants.ScopeUserRead });
                var me = await graphApiOperations.GetUserInformation(accessToken);
                var photo = await graphApiOperations.GetPhotoAsBase64Async(accessToken);

                ViewData["Me"] = me;
                ViewData["Photo"] = photo;

                logger.LogInformation("Profile data retrieved successfully.");
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error retrieving profile data.");
                throw;
            }

            return View();
        }

        [AuthorizeForScopes(Scopes = new[] { "https://management.core.windows.net/user_impersonation", "user.read", "directory.read.all" })]
        public async Task<IActionResult> Tenants()
        {
            logger.LogInformation("Tenants action called.");
            try
            {
                var accessToken = await tokenAcquisition.GetAccessTokenForUserAsync(new[] { $"{ArmApiOperationService.ArmResource}user_impersonation" });
                var tenantIds = await armOperations.EnumerateTenantsIdsAccessibleByUser(accessToken);

                ViewData["tenants"] = tenantIds;

                logger.LogInformation("Tenant IDs retrieved successfully.");
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error retrieving tenant IDs.");
                throw;
            }

            return View();
        }

        [AuthorizeForScopes(Scopes = new[] { "https://management.core.windows.net/user_impersonation" })]
        public async Task<IActionResult> TenantsWithImplicitAuth()
        {
            logger.LogInformation("TenantsWithImplicitAuth action called.");
            try
            {
                var tenantIds = await armOperationsWithImplicitAuth.EnumerateTenantsIds();

                ViewData["tenants"] = tenantIds;

                logger.LogInformation("Tenant IDs with implicit auth retrieved successfully.");
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error retrieving tenant IDs with implicit auth.");
                throw;
            }

            return View(nameof(Tenants));
        }

        [AuthorizeForScopes(Scopes = new[] { "https://storage.azure.com/user_impersonation" })]
        public async Task<IActionResult> Blob()
        {
            logger.LogInformation("Blob action called.");
            string message = "Blob failed to create";
            var blobFileSuffixDateTime = DateTime.Now.ToString("yyyyMMddHHmmss");
            Uri blobUri = new Uri($"https://stekmsalpower001.blob.core.windows.net/sysadmincontainer/Blob_{blobFileSuffixDateTime}.txt");
            BlobClient blobClient = new BlobClient(blobUri, new TokenAcquisitionTokenCredential(tokenAcquisition));

            string blobContents = "Blob created by Azure AD authenticated user.";
            byte[] byteArray = Encoding.ASCII.GetBytes(blobContents);
            using (MemoryStream stream = new MemoryStream(byteArray))
            {
                try
                {
                    await blobClient.UploadAsync(stream);
                    message = "Blob successfully created";
                    logger.LogInformation("Blob created successfully.");
                }
                catch (MicrosoftIdentityWebChallengeUserException ex)
                {
                    logger.LogError(ex, "MicrosoftIdentityWebChallengeUserException occurred while creating blob.");
                    throw;
                }
                catch (MsalUiRequiredException ex)
                {
                    logger.LogError(ex, "MsalUiRequiredException occurred while creating blob.");
                    throw;
                }
                catch (Exception ex)
                {
                    try
                    {
                        message += $". Reason - {((Azure.RequestFailedException)ex).ErrorCode}";
                        logger.LogError(ex, "RequestFailedException occurred while creating blob.");
                    }
                    catch (Exception innerEx)
                    {
                        message += $". Reason - {ex.Message}";
                        logger.LogError(innerEx, "Exception occurred while creating blob.");
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
            logger.LogError("Error action called.");
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}
