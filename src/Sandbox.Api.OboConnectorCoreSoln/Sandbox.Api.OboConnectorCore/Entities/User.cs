namespace Sandbox.Api.OboConnectorCore.Entities
{
    public class User
    {
        public dynamic Id { get; internal set; }
        public dynamic FullName { get; internal set; }
        public dynamic DomainName { get; internal set; }
        public dynamic Title { get; internal set; }
        public dynamic AzureActiveDirectoryObjectId { get; internal set; }
    }
}
