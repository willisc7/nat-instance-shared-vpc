#Create a static IP address for the NAT gateway
resource "google_compute_address" "nat_instance_ip" {
  name    = "${var.host_project}-nat-instance-ip-${var.region}"
  region  = var.region
  project = var.host_project
}

resource "google_compute_global_address" "google_reserved_range" {
  name          = "google-reserved-range"
  prefix_length = 16
  description   = "peering range for Google service"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  network       = google_compute_network.tfer--vpc-hub.self_link
}

# Create a NAT VM and configure it to perform NAT functions
resource "google_compute_instance" "nat_instance" {
  name         = "nat-instance"
  machine_type = "g1-small"
  zone         = "${var.region}-a"

  can_ip_forward            = true
  allow_stopping_for_update = true

  tags = ["nat"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.tfer--vpc-hub.self_link
    subnetwork = google_compute_subnetwork.network1["subnet_name"].self_link
    network_ip = "192.168.0.10"
  }

  # Example: this will route any packets destined for the IP of ifconfig.me or the two major AWS IP ranges to the nat-instance's default gateway
  metadata_startup_script = <<-EOT
    #! /bin/bash
    sudo sysctl net.ipv4.conf.all.forwarding=1
    sudo iptables -F && sudo iptables -F -tnat 
    sudo iptables --table nat --append POSTROUTING --out-interface ens4 -j MASQUERADE
    sudo ip route add default via 192.168.0.1 dev ens4

    
    sudo ip route add ${var.ifconfig_me_range} via 192.168.0.1 dev ens4    
    sudo ip route add ${var.AWS_range} via 192.168.0.1 dev ens4
    sudo ip route add ${var.AWS_range2} via 192.168.0.1 dev ens4
  EOT

  lifecycle {
    ignore_changes = [
      metadata["ssh-keys"]
    ]
  }

}

# Create routes to forward traffic destined for a specific IP range to the nat-instance
# AMAZON RANGES https://aws.amazon.com/de/blogs/aws/aws-ip-ranges-json/
resource "google_compute_route" "tf-50_amazon_to_nat_instance" {
  name              = "tf-50-amazon-to-nat-instance"
  dest_range        = var.AWS_range
  network           = google_compute_network.tfer--vpc-hub.self_link
  next_hop_instance = google_compute_instance.nat_instance.self_link
  priority          = 300 # so it does not collide with the 1000 Default internet gateway routes
}

resource "google_compute_route" "tf-54_amazon_to_nat_instance" {
  name              = "tf-54-amazon-to-nat-instance"
  dest_range        = var.AWS_range2
  network           = google_compute_network.tfer--vpc-hub.self_link
  next_hop_instance = google_compute_instance.nat_instance.self_link
  priority          = 300 # so it does not collide with the 1000 Default internet gateway routes
}

# curl ifconfig.me/ip RANGE
resource "google_compute_route" "tf-34_ifconfigme_to_nat_instance" {
  name              = "tf-34-ifconfigme-to-nat-instance"
  dest_range        = var.ifconfig_me_range
  network           = google_compute_network.tfer--vpc-hub.self_link
  next_hop_instance = google_compute_instance.nat_instance.self_link
  priority          = 300 # so it does not collide with the 1000 Default internet gateway routes
}

resource "google_compute_route" "tf-50_amazon_to_nat_instance_tagged" {
  name             = "tf-50-amazon-to-nat-instance-tagged"
  dest_range       = var.AWS_range
  network          = google_compute_network.tfer--vpc-hub.self_link
  next_hop_gateway = "default-internet-gateway"
  priority         = 200
  tags             = ["nat"]
}

resource "google_compute_route" "tf-54_amazon_to_nat_instance_tagged" {
  name             = "tf-54-amazon-to-nat-instance-tagged"
  dest_range       = var.AWS_range2
  network          = google_compute_network.tfer--vpc-hub.self_link
  next_hop_gateway = "default-internet-gateway"
  priority         = 200
  tags             = ["nat"]
}

#curl ifconfig.me/ip RANGE
resource "google_compute_route" "tf-34_ifconfigme_to_nat_instance_tagged" {
  name             = "tf-34-ifconfigme-to-nat-instance-tagged"
  dest_range       = var.ifconfig_me_range
  network          = google_compute_network.tfer--vpc-hub.self_link
  next_hop_gateway = "default-internet-gateway"
  priority         = 200
  tags             = ["nat"]
}

resource "google_compute_route" "tf-nat-instance-default-route" {
  name             = "tf-nat-instance-default-route"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.tfer--vpc-hub.self_link
  next_hop_gateway = "default-internet-gateway"
  priority         = 300
  tags             = ["nat"]
}

#RAN gcloud services vpc-peerings disable-vpc-service-controls --network=vpc-hub
#RAN gcloud services vpc-peerings disable-vpc-service-controls --network=external
