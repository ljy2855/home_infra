output "k8s_node_ips" {
  value = [for i in openstack_compute_instance_v2.k8s_node : i.access_ip_v4]
}
