using Appointment.Models;
using Appointments.Models;
using System.Runtime.CompilerServices;


namespace Appointments.Extensions
{
    public static class CustomerAppointmentExtensions
    {



        public static AppointmentEntity ToAppointmentEntity(this CustomerAppointment appointment)
        {
            return new AppointmentEntity(appointment.CustomerId, appointment.Id)
            {
                Subject = appointment.Subject,
                Description = appointment.Description,
                Location = appointment.Location,
                StartTime = appointment.StartTime,
                EndTime = appointment.EndTime
            };
        }


        public static CustomerAppointment ToCustomerAppointment(this AppointmentEntity appointmentEntity)
        {
            return new CustomerAppointment
            {
                CustomerId = appointmentEntity.PartitionKey,
                Id = appointmentEntity.RowKey,
                Subject = appointmentEntity.Subject,
                Description = appointmentEntity.Description,
                Location = appointmentEntity.Location,
                StartTime = appointmentEntity.StartTime,
                EndTime = appointmentEntity.EndTime
            };
        }
    }
}
