# Ansible Cheat Sheet

## Goal

Run repeatable configuration against an inventory and understand idempotency.

## Steps

1. Inspect inventory: `cat inventory.ini`
2. Check hosts: `ansible all -i inventory.ini -m ping`
3. Syntax check: `ansible-playbook -i inventory.ini playbook.yml --syntax-check`
4. Dry run when possible: `ansible-playbook -i inventory.ini playbook.yml --check`
5. Run playbook: `ansible-playbook -i inventory.ini playbook.yml`
6. Run it again and confirm fewer changes.

## Done Looks Like

The second run is boring because the desired state already exists.
