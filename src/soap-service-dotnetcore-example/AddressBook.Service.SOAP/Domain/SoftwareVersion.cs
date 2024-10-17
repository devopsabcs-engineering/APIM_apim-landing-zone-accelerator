using System.Runtime.Serialization;

namespace AddressBook.Service.SOAP.Domain
{
    [DataContract]
    public class SoftwareVersion
    {
        [DataMember] public long Id { get; set; }
        [DataMember] public long Major { get; set; }
        [DataMember] public long Minor { get; set; }
        //[DataMember] public long Patch { get; set; }
        [DataMember] public long Build { get; set; }
        [DataMember] public long Revision { get; set; }
        [DataMember] public string SemanticVersion { get; set; }
    }
}
