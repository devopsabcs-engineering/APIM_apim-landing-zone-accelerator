using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Appointments.Models
{
    public class CustomerAppointment
    {

        public string CustomerId { get; set; }

        public DateTime StartTime { get; set; }

        public DateTime EndTime { get; set; }

        public string Description { get; set; }

        public string Id { get; set; }

        public string Location { get; set; }

        public string Subject { get; set; }


    }
}
