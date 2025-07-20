variable "auth_url" {}
variable "tenant_name" {}
variable "user_name" {}
variable "password" {}
variable "domain_name" {}
variable "region" {
  default = "RegionOne"
}

variable "image_name" {
  default = "ubuntu-22.04"
}

variable "flavor_name" {
  default = "ds1G"
}

variable "keypair" {
  default = "my-key"
}

variable "node_count" {
  type	  = number
  default = 3
}
variable "network_id" {}
