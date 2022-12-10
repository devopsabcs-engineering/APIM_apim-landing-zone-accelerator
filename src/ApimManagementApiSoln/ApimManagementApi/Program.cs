using System.Text;
using System.Globalization;
using System.Security.Cryptography;

public class Program
{
    public static void Main()
    {
        var id = Environment.GetEnvironmentVariable("APIM_LandingZone_RestApi_Identifier");
        var key = Environment.GetEnvironmentVariable("APIM_LandingZone_RestApi_PrimaryKey");
        var expiry = DateTime.UtcNow.AddDays(10);
        using (var encoder = new HMACSHA512(Encoding.UTF8.GetBytes(key)))
        {
            var dataToSign = id + "\n" + expiry.ToString("O", CultureInfo.InvariantCulture);
            var hash = encoder.ComputeHash(Encoding.UTF8.GetBytes(dataToSign));
            var signature = Convert.ToBase64String(hash);
            var encodedToken = string.Format("SharedAccessSignature uid={0}&ex={1:o}&sn={2}", id, expiry, signature);
            Console.WriteLine(encodedToken);
        }
    }
}