provider "openstack" {
  auth_url    = var.auth_url
  tenant_name = var.tenant_name
  user_name   = var.user_name
  password    = var.password
  #domain_name = var.domain_name
}

resource "openstack_networking_network_v2" "k8s_net" {
  name = "k8s-net"
}

resource "openstack_networking_subnet_v2" "k8s_subnet" {
  name            = "k8s-subnet"
  network_id      = openstack_networking_network_v2.k8s_net.id
  cidr            = "192.168.101.0/24"
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

resource "openstack_networking_port_v2" "k8s_port" {
  count = var.node_count
  name  = "k8s-port-${count.index}"
  network_id = openstack_networking_network_v2.k8s_net.id
  security_group_ids = [openstack_networking_secgroup_v2.k8s_secgroup.id]
}

resource "openstack_compute_instance_v2" "k8s_node" {
  count       = var.node_count
  name        = "k8s-node-${count.index}"
  image_name  = var.image_name
  flavor_name = var.flavor_name
  key_pair    = var.keypair
  security_groups = [openstack_networking_secgroup_v2.k8s_secgroup.name]

  network {
    port = openstack_networking_port_v2.k8s_port[count.index].id
  }

  metadata = {
    role = count.index == 0 ? "master" : "worker"
  }

  user_data = file(count.index == 0 ? "cloud-init-master.yaml" : "cloud-init-worker.yaml")
}

resource "openstack_networking_floatingip_v2" "k8s_fip" {
  count = var.node_count
  pool  = "public"
}

resource "openstack_networking_floatingip_associate_v2" "k8s_fip_assoc" {
  count       = var.node_count
  floating_ip = openstack_networking_floatingip_v2.k8s_fip[count.index].address
  port_id     = openstack_networking_port_v2.k8s_port[count.index].id
}

data "openstack_networking_network_v2" "public" {
  name = var.pool
}

resource "openstack_networking_router_v2" "k8s_router" {
  name                = "k8s-router"
  external_network_id = data.openstack_networking_network_v2.public.id
}

resource "openstack_networking_router_interface_v2" "k8s_router_interface" {
  router_id = openstack_networking_router_v2.k8s_router.id
  subnet_id = openstack_networking_subnet_v2.k8s_subnet.id
}

output "k8s_floating_ips" {
  value = openstack_networking_floatingip_v2.k8s_fip[*].address
}
