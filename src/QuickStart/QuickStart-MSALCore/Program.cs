using Microsoft.Identity.Client;
using Newtonsoft.Json.Linq;
using System;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;

namespace PowerApps.Samples
{
    class Program
    {
        static void Main()
        {
            //https://learn.microsoft.com/en-us/entra/msal/dotnet/acquiring-tokens/using-web-browsers#how-to-use-the-default-system-browser

            // avoid error
            // System.AggregateException
            //            HResult = 0x80131500
            //  Message = One or more errors occurred. (Only loopback redirect uri is supported, but app://58145b91-0c36-4500-8554-080854f2ac97/ was found. Configure http://localhost or http://localhost:port both during app registration and when you create the PublicClientApplication object. See https://aka.ms/msal-net-os-browser for details)
            //  Source = System.Private.CoreLib
            //  StackTrace:
            //            at System.Threading.Tasks.Task.ThrowIfExceptional(Boolean includeTaskCanceledExceptions)
            //   at System.Threading.Tasks.Task`1.GetResultCore(Boolean waitCompletionNotification)
            //   at PowerApps.Samples.Program.Main() in C:\src\devopsabcs\OneProject\APIM_apim - landing - zone - accelerator\src\QuickStart\QuickStart - MSALCore\Program.cs:line 39

            //  This exception was originally thrown at this call stack:
            //    [External Code]

            //            Inner Exception 1:
            //MsalClientException: Only loopback redirect uri is supported, but app://58145b91-0c36-4500-8554-080854f2ac97/ was found. Configure http://localhost or http://localhost:port both during app registration and when you create the PublicClientApplication object. See https://aka.ms/msal-net-os-browser for details


            string dataVerseEnvironmentName = "org50078be4";// "crmue";

            // TODO Specify the Dataverse environment name to connect with.
            string resource = $"https://{dataVerseEnvironmentName}.crm.dynamics.com";

            // Azure Active Directory app registration shared by all Power App samples.
            // For your custom apps, you will need to register them with Azure AD yourself.
            // See https://learn.microsoft.com/powerapps/developer/data-platform/walkthrough-register-app-azure-active-directory
            //var clientId = "51f81489-12ee-4a9e-aaae-a2591f45987d";
            //var redirectUri = "app://58145B91-0C36-4500-8554-080854F2AC97";


            // also avoid error
            // System.AggregateException
            //  HResult=0x80131500
            //  Message=One or more errors occurred. (A configuration issue is preventing authentication - check the error message from the server for details. You can modify the configuration in the application registration portal. See https://aka.ms/msal-net-invalid-client for details.  Original exception: AADSTS7000218: The request body must contain the following parameter: 'client_assertion' or 'client_secret'. Trace ID: 8274b049-64cc-44ba-8331-35f4e4f67000 Correlation ID: 1b9873b9-e45b-4638-a959-7bc71630c20c Timestamp: 2024-11-25 19:14:32Z)
            //  Source=System.Private.CoreLib
            //  StackTrace:
            //   at System.Threading.Tasks.Task.ThrowIfExceptional(Boolean includeTaskCanceledExceptions)
            //   at System.Threading.Tasks.Task`1.GetResultCore(Boolean waitCompletionNotification)
            //   at PowerApps.Samples.Program.Main() in C:\src\devopsabcs\OneProject\APIM_apim-landing-zone-accelerator\src\QuickStart\QuickStart-MSALCore\Program.cs:line 57

            //  This exception was originally thrown at this call stack:
            //    [External Code]

            //Inner Exception 1:
            //MsalServiceException: A configuration issue is preventing authentication - check the error message from the server for details. You can modify the configuration in the application registration portal. See https://aka.ms/msal-net-invalid-client for details.  Original exception: AADSTS7000218: The request body must contain the following parameter: 'client_assertion' or 'client_secret'. Trace ID: 8274b049-64cc-44ba-8331-35f4e4f67000 Correlation ID: 1b9873b9-e45b-4638-a959-7bc71630c20c Timestamp: 2024-11-25 19:14:32Z
            //System.AggregateException
            //  HResult=0x80131500
            //  Message=One or more errors occurred. (A configuration issue is preventing authentication - check the error message from the server for details. You can modify the configuration in the application registration portal. See https://aka.ms/msal-net-invalid-client for details.  Original exception: AADSTS7000218: The request body must contain the following parameter: 'client_assertion' or 'client_secret'. Trace ID: 8274b049-64cc-44ba-8331-35f4e4f67000 Correlation ID: 1b9873b9-e45b-4638-a959-7bc71630c20c Timestamp: 2024-11-25 19:14:32Z)
            //  Source=System.Private.CoreLib
            //  StackTrace:
            //   at System.Threading.Tasks.Task.ThrowIfExceptional(Boolean includeTaskCanceledExceptions)
            //   at System.Threading.Tasks.Task`1.GetResultCore(Boolean waitCompletionNotification)
            //   at PowerApps.Samples.Program.Main() in C:\src\devopsabcs\OneProject\APIM_apim-landing-zone-accelerator\src\QuickStart\QuickStart-MSALCore\Program.cs:line 57

            //  This exception was originally thrown at this call stack:
            //    [External Code]

            //Inner Exception 1:
            //MsalServiceException: A configuration issue is preventing authentication - check the error message from the server for details. You can modify the configuration in the application registration portal. See https://aka.ms/msal-net-invalid-client for details.  Original exception: AADSTS7000218: The request body must contain the following parameter: 'client_assertion' or 'client_secret'. Trace ID: 8274b049-64cc-44ba-8331-35f4e4f67000 Correlation ID: 1b9873b9-e45b-4638-a959-7bc71630c20c Timestamp: 2024-11-25 19:14:32Z


            // also avoid error
            //System.AggregateException
            //            HResult = 0x80131500
            //  Message = One or more errors occurred. (AADSTS50194: Application 'c4b08b47-feca-48ef-878c-59a05228cb83'(powerapps -public-client-app) is not configured as a multi-tenant application.Usage of the /common endpoint is not supported for such applications created after '10/15/2018'. Use a tenant-specific endpoint or configure the application to be multi-tenant.Trace ID: cc18875c-5a70-4928-b3f3-8474c56c6400 Correlation ID: 24728d6e-d604-47be-82be-b20ac24a1993 Timestamp: 2024-11-25 19:38:25Z)
            //  Source=System.Private.CoreLib
            //        StackTrace:
            //   at System.Threading.Tasks.Task.ThrowIfExceptional(Boolean includeTaskCanceledExceptions)
            //   at System.Threading.Tasks.Task`1.GetResultCore(Boolean waitCompletionNotification)
            //   at PowerApps.Samples.Program.Main() in C:\src\devopsabcs\OneProject\APIM_apim-landing-zone-accelerator\src\QuickStart\QuickStart-MSALCore\Program.cs:line 107

            //  This exception was originally thrown at this call stack:
            //    [External Code]

            //Inner Exception 1:
            //MsalServiceException: AADSTS50194: Application 'c4b08b47-feca-48ef-878c-59a05228cb83'(powerapps-public-client-app) is not configured as a multi-tenant application.Usage of the /common endpoint is not supported for such applications created after '10/15/2018'. Use a tenant-specific endpoint or configure the application to be multi-tenant.Trace ID: cc18875c-5a70-4928-b3f3-8474c56c6400 Correlation ID: 24728d6e-d604-47be-82be-b20ac24a1993 Timestamp: 2024-11-25 19:38:25Z




            #region Authentication

            //var clientSecret = "your client secret";
            //var authBuilder = ConfidentialClientApplicationBuilder.Create(clientId)
            //                 .WithClientSecret(clientSecret)
            //                 .WithAuthority(AadAuthorityAudience.AzureAdMultipleOrgs)
            //                 .WithRedirectUri(redirectUri)
            //                    .Build();
            //var scope = $"{resource}/.default";

            //var authBuilder = PublicClientApplicationBuilder.Create(clientId)
            //                 .WithAuthority(AadAuthorityAudience.AzureAdMultipleOrgs)
            //                 .WithRedirectUri(redirectUri)
            //                 .Build();

            var clientId = "c4b08b47-feca-48ef-878c-59a05228cb83";
            var redirectUri = "http://localhost";
            var scope = resource + "/user_impersonation";
            AuthenticationResult token = GetAuthTokenPublicClientApp(resource, clientId, redirectUri, scope);

            //AuthenticationResult token =
            //    authBuilder.AcquireTokenInteractive(scopes).ExecuteAsync().Result;
            Console.WriteLine(token.AccessToken);

            //decode the token
            var handler = new JwtSecurityTokenHandler();
            var jsonToken = handler.ReadToken(token.AccessToken) as JwtSecurityToken;
            Console.WriteLine(jsonToken.Claims.First(claim => claim.Type == "name").Value);

            // give full output as with https://jwt.ms or https://jwt.io
            // decode all claims
            foreach (var claim in jsonToken.Claims)
            {
                Console.WriteLine($"{claim.Type}: {claim.Value}");
            }
            // give audiences
            Console.WriteLine("Audiences: " + string.Join(", ", jsonToken.Audiences));
            // give valid from and to
            Console.WriteLine("Valid from: " + jsonToken.ValidFrom);
            Console.WriteLine("Valid to: " + jsonToken.ValidTo);



            #endregion Authentication

            #region Client configuration

            var client = new HttpClient
            {
                // See https://learn.microsoft.com/powerapps/developer/data-platform/webapi/compose-http-requests-handle-errors#web-api-url-and-versions
                BaseAddress = new Uri(resource + "/api/data/v9.2/"),
                Timeout = new TimeSpan(0, 2, 0)    // Standard two minute timeout on web service calls.
            };

            // Default headers for each Web API call.
            // See https://learn.microsoft.com/powerapps/developer/data-platform/webapi/compose-http-requests-handle-errors#http-headers
            HttpRequestHeaders headers = client.DefaultRequestHeaders;
            headers.Authorization = new AuthenticationHeaderValue("Bearer", token.AccessToken);
            headers.Add("OData-MaxVersion", "4.0");
            headers.Add("OData-Version", "4.0");
            headers.Accept.Add(
                new MediaTypeWithQualityHeaderValue("application/json"));
            #endregion Client configuration

            #region Web API call

            // Invoke the Web API 'WhoAmI' unbound function.
            // See https://learn.microsoft.com/powerapps/developer/data-platform/webapi/compose-http-requests-handle-errors
            // See https://learn.microsoft.com/powerapps/developer/data-platform/webapi/use-web-api-functions#unbound-functions
            var response = client.GetAsync("WhoAmI").Result;

            if (response.IsSuccessStatusCode)
            {
                // Parse the JSON formatted service response to obtain the user ID.  
                JObject body = JObject.Parse(
                    response.Content.ReadAsStringAsync().Result);
                // write out nicely formatted JSON
                Console.WriteLine(body.ToString());
                Guid userId = (Guid)body["UserId"];

                Console.WriteLine("Your user ID is {0}", userId);
            }
            else
            {
                Console.WriteLine("Web API call failed");
                Console.WriteLine("Reason: " + response.ReasonPhrase);
            }
            #endregion Web API call

            //// Pause program execution by waiting for a key press.
            //Console.WriteLine("Press any key to exit.");
            //Console.ReadKey();
        }

        private static AuthenticationResult GetAuthTokenPublicClientApp(
            string resource, string clientId, string redirectUri, string scope)
        {
            var authBuilder = PublicClientApplicationBuilder
                .Create(clientId)
                .WithAuthority(AadAuthorityAudience.AzureAdMultipleOrgs)
                // or use a known port if you wish "http://localhost:1234"
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
