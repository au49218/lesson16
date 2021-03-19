# rlt_terraform_k8s_test
This repo holds the assets needed for our Terraform, Kubernetes, And Helm

## Test Overview
demo in following areas: 
* GCP
* Terraform
* Kubernetes (GKE)
* Helm

This repo holds the application code and Dockerfile in the "application" directory. The helm chart to be used to deploy the application to the Kubernetes cluster is the "charts" directory. 

Authorize gcloud tool with application token
```
gcloud auth application-default login --no-launch-browser
```
Install Docker
https://docs.docker.com/get-docker/

Install Terraform
https://www.terraform.io/downloads.html

Install Helm
https://helm.sh/docs/intro/install/

Multi Project
```
cd terraform
gcloud alpha billing accounts list --format='value(name.basename())'
terraform init
terraform apply -var="billing_account=$(gcloud alpha billing accounts list --format='value(name.basename())')"
gcloud container clusters get-credentials  walt-cluster --project=$(terraform output project) --region=$(terraform output region)
gcloud auth configure-docker
docker build -t rlt-test ../application/rlt-test
docker tag rlt-test $(terraform output gcr)/rlt-test
docker push $(terraform output gcr)/rlt-test

helm install --set image.repository="$(terraform output gcr)/rlt-test" walt-stage ../charts/rlt-test/
helm uninstall walt-stage
terraform destroy -var="billing_account=$(gcloud alpha billing accounts list --format='value(name.basename())')"
```

Single Project
```
cd terraform
terraform init
terraform apply -var="project=devops-295901"
gcloud container clusters get-credentials  walt-cluster --project=$(terraform output project) --region=$(terraform output region)
gcloud auth configure-docker
docker build -t rlt-test ../application/rlt-test
docker tag rlt-test $(terraform output gcr)/rlt-test
docker push $(terraform output gcr)/rlt-test

helm install --set image.repository="$(terraform output gcr)/rlt-test" walt-stage ../charts/rlt-test/
helm uninstall walt-stage
terraform destroy -var="project=devops-295901"
```

