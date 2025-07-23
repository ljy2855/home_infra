output "k8s_master_floating_ip" {
  value = openstack_networking_floatingip_v2.k8s_master_fip.address
}

output "k8s_worker_floating_ips" {
  value = openstack_networking_floatingip_v2.k8s_worker_fip[*].address
}
