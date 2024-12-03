//using Newtonsoft.Json;
//using System.Net.Http;
//using System.Threading.Tasks;
//using System.Xml.Linq;

//public class Script : ScriptBase
//{
//    public override async Task<HttpResponseMessage> ExecuteAsync()
//    {
//        // Get the original response
//        var originalResponse = await this.Context.SendAsync(this.Context.Request, default).ConfigureAwait(false);

//        // Read the response content as a string
//        var xmlContent = await originalResponse.Content.ReadAsStringAsync().ConfigureAwait(false);

//        // Convert XML to JSON
//        var xmlDoc = XDocument.Parse(xmlContent);
//        var jsonContent = JsonConvert.SerializeXNode(xmlDoc, Newtonsoft.Json.Formatting.Indented);

//        // Create a new response with JSON content
//        var jsonResponse = new HttpResponseMessage(originalResponse.StatusCode)
//        {
//            Content = new StringContent(jsonContent, System.Text.Encoding.UTF8, "application/json")
//        };

//        return jsonResponse;
//    }
//}
