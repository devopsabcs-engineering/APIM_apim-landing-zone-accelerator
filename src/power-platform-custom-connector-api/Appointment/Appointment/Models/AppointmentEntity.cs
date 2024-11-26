

using Azure;
using Azure.Data.Tables;

namespace Appointment.Models
{
    public class AppointmentEntity : ITableEntity
    {
        public string PartitionKey { get; set; }
        public string RowKey { get; set; }
        public DateTimeOffset? Timestamp { get; set; }
        public ETag ETag { get; set; }

        // Other properties
        public string Subject { get; set; }
        public string Description { get; set; }
        public string Location { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }

        // Parameterless constructor
        public AppointmentEntity() { }

        // Constructor with parameters
        public AppointmentEntity(string partitionKey, string rowKey)
        {
            PartitionKey = partitionKey;
            RowKey = rowKey;
        }
    }
}