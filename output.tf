output "bastion_eip" {
  value = "${g42cloud_vpc_eip.eip_bastion.address}"
}