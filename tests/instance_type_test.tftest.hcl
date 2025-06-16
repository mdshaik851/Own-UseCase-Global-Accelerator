variables {
  instance_type = "t2.micro"  # Set the expected instance type
}

run "verify_instance_type" {
  command = plan

  # Assert that the instance type matches what we specified
  assert {
    condition     = aws_instance.app_primary.instance_type == var.instance_type
    error_message = "Instance type mismatch"
  }
}