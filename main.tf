provider "openstack" {
  auth_url    = var.auth_url
  tenant_name = var.tenant_name
  user_name   = var.user_name
  password    = var.password
  domain_name = var.domain_name
}

resource "openstack_networking_network_v2" "k8s_net" {
  name = "k8s-net"
}

resource "openstack_networking_subnet_v2" "k8s_subnet" {
  name            = "k8s-subnet"
  network_id      = openstack_networking_network_v2.k8s_net.id
  cidr            = "192.168.100.0/24"
  ip_version      = 4
  dns_nameservers = ["8.8.8.8"]
}

resource "openstack_networking_secgroup_v2" "k8s_secgroup" {
  name        = "k8s-secgroup"
  description = "Allow SSH and Kubernetes ports"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
}

resource "openstack_compute_instance_v2" "k8s_node" {
  count       = var.node_count
  name        = "k8s-node-${count.index}"
  image_name  = var.image_name
  flavor_name = var.flavor_name
  key_pair    = var.keypair
  security_groups = [openstack_networking_secgroup_v2.k8s_secgroup.name]

  network {
    uuid = openstack_networking_network_v2.k8s_net.id
  }

  metadata = {
    role = count.index == 0 ? "master" : "worker"
  }

  user_data = file(count.index == 0 ? "cloud-init-master.yaml" : "cloud-init-worker.yaml")
}
