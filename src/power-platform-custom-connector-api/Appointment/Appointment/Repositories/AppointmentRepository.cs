using Appointment.Models;
using Appointments.Interfaces;
using Azure;
using Azure.Data.Tables;
using System;
using System.Threading.Tasks;

namespace Appointments.Repositories
{
    public class AppointmentRepository : IAppointmentRepository
    {
        private readonly TableClient _tableClient;

        public AppointmentRepository(string connectionString, string tableName)
        {

            var tableServiceClient = new TableServiceClient(connectionString);
            _tableClient = tableServiceClient.GetTableClient(tableName);
        }

        public async Task CreateAppointmentAsync(AppointmentEntity appointment)
        {
          await _tableClient.AddEntityAsync(appointment);
     
        }

        public async Task<AppointmentEntity> GetAppointmentAsync(string partitionKey, string rowKey)
        {
            return await _tableClient.GetEntityAsync<AppointmentEntity>(partitionKey, rowKey);
        }


        public async Task UpdateAppointmentAsync(AppointmentEntity appointment)
        {
            await _tableClient.UpdateEntityAsync(appointment, ETag.All, TableUpdateMode.Replace);
        }

        public async Task DeleteAppointmentAsync(string partitionKey, string rowKey)
        {
            await _tableClient.DeleteEntityAsync(partitionKey, rowKey, ETag.All);
        }


        public async Task<List<AppointmentEntity>> GetAppointmentsAsync(string customerId)
        {

            List<AppointmentEntity> appointments = new List<AppointmentEntity>();

            // Query the table for entities with the specified partition key
            await foreach (var appointment in _tableClient.QueryAsync<AppointmentEntity>(x => x.PartitionKey == customerId))
            {
                appointments.Add(appointment);
            }
            return appointments;

        }

    }


}