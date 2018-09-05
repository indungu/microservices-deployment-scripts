# Microservices Deployment Scripts
A repo for the deployment scripts used to setup a deployment pipeline for the [microservices-app-example](https://github.com/indungu/microservice-app-example.git).

## Contents
This repo contains the following

1. A packer template file `packer.json` for creating an AMI on AWS. The Image is privisioned with Ansible and basic file uploads.
2. An Ansible playbook `playbook.yml` that inplements set of tasks defined in the `roles` folder
3. A `roles` folder contains a set of subfolders each of which implements a set of setup specific tasks
4. A `k8s_setup.sh` script which is copied into the image and is used to create a Kuberneters cluster on AWS
---
## Building image
To build the image ensure you have both [Packer](https://packer.io/intro/index.html) and [Ansible](https://www.ansible.com/resources/get-started) installed.
If you are new to configuration managemant, you may consider using this introductory demo I did on the subject. Follow [this here article](https://medium.com/@isaacndungu/change-and-configuration-management-the-devops-way-f23e66ecdeea) to get you up to speed.

Installing pre-requisites

**Packer**

    brew install packer

**ansible**

    brew install ansible

To build the image do
**Clone the repo**
```bash
git clone https://github.com/indungu/microservices-deployment-scripts
cd microservices-deployment-scripts
```
**Create .env fil*e*
```bash
aws configure  # fill in the prompts appropriately
cat ~/.aws/credentials > .env # create the env file from the credentials you supplied
```
**Build the image**

```
packer build packer.json
```
---
## Setting up the instance
Once the AMI is created successfully, launch an instance with it and run the `k8s_setup.sh` script as shown below.

```bash
ubuntu@instance_local_ip~$ source k8s_setup.sh
```
---
## Conclusion
When this is done, you will have access to a jenkins instance that has: awscli, kops, kubernetes, docker, docker-compose, kubectl and nginx for reverse proxy to the Jenkins server.

Running the script will also create a cluster as set in the `user defined variables` section. Be sure to edit this section with the appropriate variables.
