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

# master port
resource "openstack_networking_port_v2" "k8s_master_port" {
  name               = "k8s-master-port"
  network_id         = openstack_networking_network_v2.k8s_net.id
  security_group_ids = [openstack_networking_secgroup_v2.k8s_secgroup.id]

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.k8s_subnet.id
  }
}

# worker ports
resource "openstack_networking_port_v2" "k8s_worker_port" {
  count              = var.node_count - 1
  name               = "k8s-worker-port-${count.index}"
  network_id         = openstack_networking_network_v2.k8s_net.id
  security_group_ids = [openstack_networking_secgroup_v2.k8s_secgroup.id]

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.k8s_subnet.id
  }
}

# master instance
resource "openstack_compute_instance_v2" "k8s_master" {
  name            = "k8s-master"
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  key_pair        = var.keypair
  security_groups = [openstack_networking_secgroup_v2.k8s_secgroup.name]
  network {
    port = openstack_networking_port_v2.k8s_master_port.id
  }
  metadata = {
    role = "master"
  }
  user_data = file("cloud-init-master.yaml")
}

# worker instances
resource "openstack_compute_instance_v2" "k8s_worker" {
  count           = var.node_count - 1
  name            = "k8s-worker-${count.index}"
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  key_pair        = var.keypair
  security_groups = [openstack_networking_secgroup_v2.k8s_secgroup.name]
  network {
    port = openstack_networking_port_v2.k8s_worker_port[count.index].id
  }
  metadata = {
    role = "worker"
  }
  user_data  = file("cloud-init-worker.yaml")
  depends_on = [openstack_compute_instance_v2.k8s_master]
}

# master floating ip
resource "openstack_networking_floatingip_v2" "k8s_master_fip" {
  pool = "public"
}

resource "openstack_networking_floatingip_associate_v2" "k8s_master_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.k8s_master_fip.address
  port_id     = openstack_networking_port_v2.k8s_master_port.id
}

# worker floating ips
resource "openstack_networking_floatingip_v2" "k8s_worker_fip" {
  count = var.node_count - 1
  pool  = "public"
}

resource "openstack_networking_floatingip_associate_v2" "k8s_worker_fip_assoc" {
  count       = var.node_count - 1
  floating_ip = openstack_networking_floatingip_v2.k8s_worker_fip[count.index].address
  port_id     = openstack_networking_port_v2.k8s_worker_port[count.index].id
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

resource "openstack_networking_secgroup_rule_v2" "k8s_apiserver" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
}

