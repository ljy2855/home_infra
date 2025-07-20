terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.50"  # 원하는 버전 명시
    }
  }
  required_version = ">= 1.0"
}
