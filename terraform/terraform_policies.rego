package terraform.policies

# Deny VPCs missing required tags
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_instance"
    missing_tags := {"Name"} - {t | resource.change.after.tags[t]}
    count(missing_tags) > 0
    msg := sprintf("VPC '%s' is missing required tags: %v", [resource.address, missing_tags])
}