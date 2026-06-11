# Terraform Cheat Sheet

## Goal

Make infrastructure changes predictable with format, validate, plan, apply, and
destroy.

## Steps

1. Format: `terraform fmt`
2. Initialize: `terraform init`
3. Validate: `terraform validate`
4. Preview: `terraform plan`
5. Apply only when expected: `terraform apply`
6. Inspect state: `terraform state list`
7. Clean up: `terraform destroy`

## Done Looks Like

You never apply before reading a plan, and you can explain what Terraform state
is tracking.
