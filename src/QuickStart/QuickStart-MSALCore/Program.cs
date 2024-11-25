using Microsoft.Extensions.Configuration;
using Microsoft.Identity.Client;
using Newtonsoft.Json.Linq;
using System;
using System.IdentityModel.Tokens.Jwt;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;

namespace PowerApps.Samples
{
    class Program
    {
        static void Main()
        {
            // TODO: Set isPublicClient to false for confidential client
            bool isPublicClient = true; // Set to false for confidential client
            string apiVersion = "v9.2"; // Set to the version of the Web API you are using
            string dataVerseEnvironmentName = "org50078be4"; // Set to the environment name of your Dataverse environment
            
            string resource = $"https://{dataVerseEnvironmentName}.crm.dynamics.com";

            var configuration = new ConfigurationBuilder()
                .SetBasePath(Directory.GetCurrentDirectory())
                .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
                .Build();

            AuthenticationResult token = null;

            if (isPublicClient)
            {
                Console.WriteLine("Public client");
                var clientId = "c4b08b47-feca-48ef-878c-59a05228cb83";
                var redirectUri = "http://localhost";
                var scope = resource + "/user_impersonation";
                token = GetAuthTokenPublicClientApp(resource, clientId, redirectUri, scope);
            }
            else
            {
                Console.WriteLine("Confidential client");
                var clientId = "7f302f1f-081d-4a3b-bd84-3bbcee7a0a12";
                var redirectUri = "http://localhost";
                var scope = resource + "/.default";
                var clientSecret = configuration["AzureAd:ClientSecret"];
                var tenantId = "aa93b9d9-037d-4f08-a26d-783cff0e2369";
                token = GetAuthTokenConfidentialClientApp(
                    resource, clientId, clientSecret, redirectUri, scope,
                    tenantId);
            }

            Console.WriteLine("------------- Token -------------------");
            Console.WriteLine(token.AccessToken);
            Console.WriteLine("------------- Token -------------------\n");

            var handler = new JwtSecurityTokenHandler();
            var jsonToken = handler.ReadToken(token.AccessToken) as JwtSecurityToken;
            Console.WriteLine("--------------- Name or App Id -----------------");
            if (isPublicClient)
            {
                Console.WriteLine(jsonToken.Claims.First(claim => claim.Type == "name").Value);
            }
            else
            {
                Console.WriteLine(jsonToken.Claims.First(claim => claim.Type == "appid").Value);
            }

            Console.WriteLine("-------------- Claims --------------------");
            foreach (var claim in jsonToken.Claims)
            {
                Console.WriteLine($"{claim.Type}: {claim.Value}");
            }
            Console.WriteLine("-------------- Audiences --------------------");
            Console.WriteLine("Audiences: " + string.Join(", ", jsonToken.Audiences));
            Console.WriteLine("-------------- Valid from and to --------------------");
            Console.WriteLine("Valid from: " + jsonToken.ValidFrom);
            Console.WriteLine("Valid to: " + jsonToken.ValidTo);
            Console.WriteLine("--------------------------------\n");

            var client = new HttpClient
            {
                BaseAddress = new Uri(resource + $"/api/data/{apiVersion}/"),
                Timeout = new TimeSpan(0, 2, 0)
            };

            HttpRequestHeaders headers = client.DefaultRequestHeaders;
            headers.Authorization = new AuthenticationHeaderValue("Bearer", token.AccessToken);
            headers.Add("OData-MaxVersion", "4.0");
            headers.Add("OData-Version", "4.0");
            headers.Accept.Add(
                new MediaTypeWithQualityHeaderValue("application/json"));

            var response = client.GetAsync("WhoAmI").Result;

            if (response.IsSuccessStatusCode)
            {
                JObject body = JObject.Parse(
                    response.Content.ReadAsStringAsync().Result);
                Console.WriteLine(body.ToString());
                Guid userId = (Guid)body["UserId"];

                Console.WriteLine("Your user ID is {0}", userId);
            }
            else
            {
                Console.WriteLine("Web API call failed");
                Console.WriteLine("Reason: " + response.ReasonPhrase);
            }
        }

        private static AuthenticationResult GetAuthTokenConfidentialClientApp(
            string resource,
            string clientId,
            string clientSecret,
            string redirectUri,
            string scope,
            string tenantId)
        {
            var authBuilder = ConfidentialClientApplicationBuilder.Create(clientId)
                             .WithTenantId(tenantId)
                             .WithClientSecret(clientSecret)
                             .WithRedirectUri(redirectUri)
                             .Build();

            string[] scopes = { scope };

            AuthenticationResult token = authBuilder.AcquireTokenForClient(scopes)
                .ExecuteAsync().Result;

            return token;
        }

        private static AuthenticationResult GetAuthTokenPublicClientApp(
            string resource,
            string clientId,
            string redirectUri,
            string scope)
        {
            var authBuilder = PublicClientApplicationBuilder
                .Create(clientId)
                .WithAuthority(AadAuthorityAudience.AzureAdMultipleOrgs)
                .WithRedirectUri(redirectUri)
                .Build();

            string[] scopes = { scope };

            AuthenticationResult token = authBuilder.AcquireTokenInteractive(scopes)
                                .WithUseEmbeddedWebView(false)
                                .ExecuteAsync().Result;
            return token;
        }
    }
}
