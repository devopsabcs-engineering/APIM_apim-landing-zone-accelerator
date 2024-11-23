using AddressBook.Service.SOAP.Domain;
using AddressBook.Service.SOAP.Repositories;
using Microsoft.Extensions.Logging;
using System.Collections.Generic;
using System.Reflection;

namespace AddressBook.Service.SOAP
{
    public class SoftwareVersionService : ISoftwareVersionService
    {
        private readonly SoftwareVersionRepository _repository;
        private readonly ILogger<SoftwareVersionRepository> _logger;
        private readonly string _version;

        public SoftwareVersionService(SoftwareVersionRepository repository,
            ILogger<SoftwareVersionRepository> logger)
        {
            _repository = repository;
            _logger = logger;

            // get version from assembly
            _version = Assembly.GetExecutingAssembly().GetName().Version.ToString();
            _logger.LogInformation("SoftwareVersionService version {version}", _version);
        }

        public IEnumerable<SoftwareVersion> GetAllSoftwareVersions()
        {
            _logger.LogInformation("Fetching all software versions. Version: {version}", _version);
            return _repository.GetAllSoftwareVersions();
        }

        public SoftwareVersion GetSoftwareVersion()
        {
            _logger.LogInformation("Fetching current software version. Version: {version}", _version);
            return _repository.GetSoftwareVersion();
        }
    }
}
