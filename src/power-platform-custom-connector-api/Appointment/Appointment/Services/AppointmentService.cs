
using Appointment.Models;
using Appointments.Extensions;
using Appointments.Interfaces;
using Appointments.Models;
using Microsoft.Extensions.Logging;

namespace Appointments.Services
{


    public class AppointmentService
    {
        private readonly ILogger<AppointmentService> _logger;
        private readonly IAppointmentRepository _appointmentRepository;

        public AppointmentService(ILogger<AppointmentService> logger, IAppointmentRepository appointmentRepository)
        {
            _logger = logger;
            _appointmentRepository = appointmentRepository;
        }

        public async Task CreateAppointmentAsync(CustomerAppointment appointment)
        {
            _logger.LogInformation("Creating appointment");

            AppointmentEntity appointmentEntity = appointment.ToAppointmentEntity();
             await _appointmentRepository.CreateAppointmentAsync(appointmentEntity);
        }

        public async Task<CustomerAppointment> GetAppointmentAsync(string customerId, string appointmentId)
        {

            _logger.LogInformation($"Deleting appointment with ID: {appointmentId} for Customer Id: {customerId}");


         

            AppointmentEntity appointmentEntity= await _appointmentRepository.GetAppointmentAsync(customerId, appointmentId);
            return appointmentEntity.ToCustomerAppointment();
        }

        public async Task UpdateAppointmentAsync(CustomerAppointment appointment)
        {
            _logger.LogInformation($"Updating appointment with ID: {appointment.Id}");
             await _appointmentRepository.UpdateAppointmentAsync(appointment.ToAppointmentEntity());
        }

        public async Task DeleteAppointmentAsync(string customerId, string appointmentId)
        {


            _logger.LogInformation($"Deleting appointment with ID: {appointmentId} for Customer Id: {customerId}");
             await _appointmentRepository.DeleteAppointmentAsync(customerId, appointmentId);
        }

        public async Task<List<CustomerAppointment>> GetAppointmentsAsync(string customerId)
        {
            List<AppointmentEntity> appointmentEntities= await _appointmentRepository.GetAppointmentsAsync(customerId);

            List<CustomerAppointment> customerAppointments = new List<CustomerAppointment>();

            foreach(var appointment in appointmentEntities)
            {
                var customerAppointment = appointment.ToCustomerAppointment();
                customerAppointments.Add(customerAppointment);

            }

            return customerAppointments;
        }



    }
}