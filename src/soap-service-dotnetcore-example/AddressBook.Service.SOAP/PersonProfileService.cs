using AddressBook.Service.SOAP.Domain;
using AddressBook.Service.SOAP.Repositories;
using Microsoft.Extensions.Logging;
using System.Collections.Generic;
using System.Reflection;

namespace AddressBook.Service.SOAP
{
    public class PersonProfileService : IPersonProfileService
    {
        private readonly PersonProfileRepository _repository;
        private readonly ILogger<PersonProfileRepository> _logger;
        private readonly string _version;

        public PersonProfileService(PersonProfileRepository repository, ILogger<PersonProfileRepository> logger)
        {
            _repository = repository;
            _logger = logger;
            // get version from assembly
            _version = Assembly.GetExecutingAssembly().GetName().Version.ToString();
            _logger.LogInformation("PersonProfileService version {version}", _version);
        }

        public IEnumerable<PersonProfile> GetAllProfiles()
        {
            _logger.LogInformation("Fetching all profiles. Version: {version}", _version);
            return _repository.FetchAll();
        }

        public PersonProfile GetProfileById(int id)
        {
            _logger.LogInformation("Fetching profile by id {id}. Version: {version}", id, _version);
            return _repository.FindById(id);
        }
    }
}