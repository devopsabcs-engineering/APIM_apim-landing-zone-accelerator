using AddressBook.Service.SOAP.Domain;
using System.Collections.Generic;
using System.Reflection;

namespace AddressBook.Service.SOAP.Repositories
{
    public class SoftwareVersionRepository
    {
        private Dictionary<long, SoftwareVersion> softwareVersions;

        public SoftwareVersionRepository()
        {
            softwareVersions = new Dictionary<long, SoftwareVersion>
            {
                {1L, new SoftwareVersion {Id = 1L, Major = 1, Minor = 0, Build = 0,  Revision = 0, SemanticVersion = "1.0.0.0"}},
                {2L, new SoftwareVersion {Id = 2L, Major = 1, Minor = 0, Build = 1,  Revision = 0, SemanticVersion = "1.0.1.0"}},
                {3L, new SoftwareVersion {Id = 3L, Major = 1, Minor = 0, Build = 2,  Revision = 0, SemanticVersion = "1.0.2.0"}}
            };
        }

        public SoftwareVersion GetSoftwareVersion()
        {
            // get actual version from the assembly
            var currentVersion = Assembly.GetExecutingAssembly().GetName().Version;
            return new SoftwareVersion
            {
                Major = currentVersion.Major,
                Minor = currentVersion.Minor,
                Build = currentVersion.Build,
                Revision = currentVersion.Revision,
                SemanticVersion = currentVersion.ToString()
            };
        }

        public IEnumerable<SoftwareVersion> GetAllSoftwareVersions()
        {
            return softwareVersions.Values;
        }
    }
}
