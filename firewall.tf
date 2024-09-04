resource "google_compute_firewall" "service_projects_to_vpc_hub_nat_instance_tf" {
  name        = "service-projects-to-vpc-hub-nat-instance-tf"
  network     = google_compute_network.tfer--vpc-hub.self_link
  description = "shared VPC subnet to NAT instance"

  priority  = 1
  direction = "INGRESS"

  #Add more ranges here for more subnets to work :D
  source_ranges = [
    "0.0.0.0/0",
    #"192.168.0.0/24"
  ]

  allow {
    protocol = "all"
  }

  project = var.host_project
}

#Firewall rule to allow traffic to come back to the NAT instance  
resource "google_compute_firewall" "nat_instance_allow_ingress" {
  name        = "nat-instance-allow-ingress"
  network     = google_compute_network.tfer--vpc-hub.self_link
  description = "Allow ingress traffic to NAT instance"

  priority      = 1000
  direction     = "INGRESS"
  source_ranges = ["${var.subnet_range1}", "${var.subnet_range2}"]

  allow {
    protocol = "all"
  }

  project = var.host_project
}
