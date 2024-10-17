using System.Collections.Generic;
using System.ServiceModel;

namespace AddressBook.Service.SOAP.Domain
{
    [ServiceContract]
    public interface ISoftwareVersionService
    {
        [OperationContract]
        public SoftwareVersion GetSoftwareVersion();

        [OperationContract]
        public IEnumerable<SoftwareVersion> GetAllSoftwareVersions();
    }
}
