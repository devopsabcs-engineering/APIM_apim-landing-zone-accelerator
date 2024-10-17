using System;
using Microsoft.AspNetCore;
using Microsoft.AspNetCore.Hosting;

namespace AddressBook.Service.SOAP.IntegrationTests
{
    public class SoapClientBase: IDisposable
    {
        private const string ProviderUri = "https://addressbookservicesoap20241016210613.azurewebsites.net"; //"https://localhost:9310";
        protected static readonly string WSDLUrl = $"{ProviderUri}/PersonProfileService.asmx";
        private bool _disposedValue;
        private readonly IWebHost _webHost;
        
        protected SoapClientBase()
        {
            _webHost = WebHost.CreateDefaultBuilder()
                .UseStartup<Startup>()
                .UseKestrel()
                .UseUrls(ProviderUri)
                .Build();
            _webHost.Start();
        }

        private void Dispose(bool disposing)
        {
            if (_disposedValue) return;
            if (disposing)
            {
                _webHost.StopAsync().GetAwaiter().GetResult();
                _webHost.Dispose();
            }

            _disposedValue = true;
        }
        
        public void Dispose()
        {
            Dispose(true);
        }
    }
}