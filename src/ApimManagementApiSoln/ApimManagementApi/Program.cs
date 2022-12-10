using System;
using System.Text;
using System.Globalization;
using System.Security.Cryptography;

public class Program
{
    public static void Main()
    {
        var id = "53d7e14aee681a0034030003";
        var key = "pXeTVcmdbU9XxH6fPcPlq8Y9D9G3Cdo5Eh2nMSgKj/DWqeSFFXDdmpz5Trv+L2hQNM+nGa704Rf8Z22W9O1jdQ==";
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