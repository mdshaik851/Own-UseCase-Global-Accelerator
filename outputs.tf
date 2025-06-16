output "global_accelerator_dns_name" {
  value = aws_globalaccelerator_accelerator.app_accelerator.dns_name
}

output "instance_type" {
  value = aws_instance.app_primary.instance_type
}