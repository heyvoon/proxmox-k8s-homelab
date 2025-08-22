.PHONY: help init plan apply destroy clean validate

# Default target
help:
	@echo "Available targets:"
	@echo "  init      - Initialize Terraform"
	@echo "  validate  - Validate Terraform configuration"
	@echo "  plan      - Plan Terraform deployment"
	@echo "  apply     - Apply Terraform configuration"
	@echo "  destroy   - Destroy infrastructure"
	@echo "  clean     - Clean temporary files"
	@echo "  check     - Check cluster status"

init:
	terraform init

validate:
	terraform validate
	cd ansible && ansible-playbook --syntax-check site.yml

plan:
	terraform plan

apply:
	terraform apply

destroy:
	terraform destroy

clean:
	rm -f terraform.tfstate*
	rm -f ansible/join_command.txt
	rm -f ansible/inventory.yml
	rm -f ansible/group_vars/all.yml

check:
	@echo "Checking cluster status..."
	@if [ -f ansible/inventory.yml ]; then \
		ansible masters -i ansible/inventory.yml -m shell -a "kubectl get nodes" || true; \
		ansible masters -i ansible/inventory.yml -m shell -a "kubectl get pods -A" || true; \
	else \
		echo "Cluster not deployed yet"; \
	fi