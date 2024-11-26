using Appointment.Models;


namespace Appointments.Interfaces
{
    public interface IAppointmentRepository
    {
        Task CreateAppointmentAsync(AppointmentEntity appointment);
        Task<AppointmentEntity> GetAppointmentAsync(string partitionKey, string rowKey);
        Task UpdateAppointmentAsync(AppointmentEntity appointment);
        Task DeleteAppointmentAsync(string partitionKey, string rowKey);
        Task<List<AppointmentEntity>> GetAppointmentsAsync(string userId);
    }
}
