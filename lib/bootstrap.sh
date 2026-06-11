# ==============================================================================
# SAMPLE DEPLOYMENT / BOOTSTRAP LOGIC
# ==============================================================================

bootstrap_sample() {
    local type=$1
    if [[ -z "$type" ]]; then
        echo -e "${RED}Error: Please specify a sample type: terraform, kubernetes, or docker.${NC}" >&2
        echo "Usage: devman bootstrap <terraform|kubernetes|docker>" >&2
        exit 1
    fi

    # Convert to lowercase
    type=$(tr '[:upper:]' '[:lower:]' <<< "$type")

    case "$type" in
        terraform|tf)
            echo -e "${GREEN}Creating sample Terraform configuration...${NC}"
            cat << 'EOF' > main.tf
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

resource "local_file" "hello" {
  filename = "${path.module}/hello_devman.txt"
  content  = "Hello from DevMan! Your Terraform installation is working perfectly.\nCreated at: ${timestamp()}\n"
}

output "message" {
  value = "Sample file created at ${local_file.hello.filename}"
}
EOF
            echo -e "${GREEN}âœ“ Created 'main.tf' in the current directory.${NC}"
            echo -e "To deploy this sample, run:"
            echo -e "  ${YELLOW}terraform init${NC}"
            echo -e "  ${YELLOW}terraform apply${NC}"
            log_message "Bootstrapped Terraform sample configuration" "SUCCESS"

            # Offer to run it if terraform is installed
            if command -v terraform &>/dev/null; then
                echo -e ""
                read -p "Would you like to run 'terraform init && terraform apply' now? (y/N): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    log_message "Applying bootstrapped Terraform sample" "INFO"
                    terraform init && terraform apply -auto-approve
                    log_message "Applied Terraform sample" "SUCCESS"
                fi
            fi
            ;;
        kubernetes|k8s)
            echo -e "${GREEN}Creating sample Kubernetes manifest...${NC}"
            cat << 'EOF' > sample-k8s.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: devman-sample-app
  labels:
    app: devman-sample
spec:
  replicas: 1
  selector:
    matchLabels:
      app: devman-sample
  template:
    metadata:
      labels:
        app: devman-sample
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: devman-sample-service
spec:
  selector:
    app: devman-sample
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
EOF
            echo -e "${GREEN}âœ“ Created 'sample-k8s.yaml' in the current directory.${NC}"
            echo -e "To deploy this sample, run:"
            echo -e "  ${YELLOW}kubectl apply -f sample-k8s.yaml${NC}"
            log_message "Bootstrapped Kubernetes sample configuration" "SUCCESS"

            if command -v kubectl &>/dev/null; then
                echo -e ""
                read -p "Would you like to run 'kubectl apply -f sample-k8s.yaml' now? (y/N): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    log_message "Applying bootstrapped Kubernetes sample" "INFO"
                    kubectl apply -f sample-k8s.yaml
                    log_message "Applied Kubernetes sample" "SUCCESS"
                fi
            fi
            ;;
        docker|compose)
            echo -e "${GREEN}Creating sample Docker Compose file...${NC}"
            cat << 'EOF' > docker-compose.yaml
version: '3.8'

services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - html_data:/usr/share/nginx/html

  redis:
    image: redis:alpine
    ports:
      - "6379:6379"

volumes:
  html_data:
EOF
            echo -e "${GREEN}âœ“ Created 'docker-compose.yaml' in the current directory.${NC}"
            echo -e "To deploy this sample, run:"
            echo -e "  ${YELLOW}docker compose up -d${NC}"
            log_message "Bootstrapped Docker Compose sample configuration" "SUCCESS"

            if command -v docker &>/dev/null; then
                echo -e ""
                read -p "Would you like to run 'docker compose up -d' now? (y/N): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    log_message "Applying bootstrapped Docker Compose sample" "INFO"
                    docker compose up -d
                    log_message "Applied Docker Compose sample" "SUCCESS"
                fi
            fi
            ;;
        *)
            echo -e "${RED}Error: Unknown sample type '$type'. Supported: terraform, kubernetes, docker.${NC}" >&2
            exit 1
            ;;
    esac
}
