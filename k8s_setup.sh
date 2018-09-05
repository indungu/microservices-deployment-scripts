#!/usr/bin/env bash

############################################################
######### A simple script that sets up a cluster ###########
#########                 on AWS                 ###########
############################################################

# User defined variables
found_bucket=false
CLUSTER_NAME=jenk8scluster1.indungu.ml
BUCKET_NAME=jenk8scluster1.indungu.ml
DNS_ZONE=indungu.ml
KEY_NAME=jaws

confirmBucketExists() {
    local buckets=$(aws s3api list-buckets --query "Buckets[].Name")
    local bucket="${BUCKET_NAME}"
    if [[ "${buckets[@]}" =~ "${bucket}" ]]; then
        found_bucket=true
        echo "found bucket ${bucket}"
    else
        echo "${bucket} not found"
    fi
}

# Creates the bucket if doesn't exist and/or sets 
# the KOPS_STATE_STORE
createBucket() {
    confirmBucketExists
    if [ $(echo $found_bucket) == false ]; then
        echo "Creating bucket ${BUCKET_NAME}"
        aws s3 mb s3://$BUCKET_NAME
    fi
    export KOPS_STATE_STORE=s3://$BUCKET_NAME
}

createKeyFile() {
    echo "Creating key file ${KEY_NAME}.pem"
    aws ec2 describe-key-pairs --key-name ${KEY_NAME} > /dev/null 2>&1;
    if [ $? > 0 ]; then
        aws ec2 create-key-pair --key-name ${KEY_NAME} | \
        jq -r '.KeyMaterial' > /home/ubuntu/.ssh/${KEY_NAME}.pem
        chmod 400 /home/ubuntu/.ssh/${KEY_NAME}.pem
    fi
}

deleteKeyFile() {
    echo "Deleting key file ${KEY_NAME}.pem"
    aws ec2 delete-key-pair --key-name ${KEY_NAME}
    rm -f /home/ubuntu/.ssh/${KEY_NAME}.pem
}

createPublicKey() {
    if [ ! $(find /home/ubuntu/.ssh/${KEY_NAME}.pub) ]; then
        if [ /home/ubuntu/.ssh/${KEY_NAME}.pem ]; then
            echo "Deleting old key pair"
            deleteKeyFile
        fi    
        createKeyFile
        ssh-keygen -y -f /home/ubuntu/.ssh/${KEY_NAME}.pem > \
        /home/ubuntu/.ssh/${KEY_NAME}.pub
    fi
    echo "Public key file aready exists"
}

createOrUpdateCluster() {
    # Only create a new cluster if one does not exist
    # else update existing cluster
    kops get clusters --name ${CLUSTER_NAME} > /dev/null 2>&1
    if [ $? == 1 ]; then
        echo "Creating cluster ${CLUSTER_NAME}"
        kops create cluster --cloud aws --zones=us-east-2b \
            --dns-zone ${DNS_ZONE} --master-size t2.micro \
            --node-size t2.micro --name ${CLUSTER_NAME} \
            --ssh-public-key /home/ubuntu/.ssh/${KEY_NAME}.pub \
            --state s3://${BUCKET_NAME} --yes

        while true; do
            kops validate cluster --name $CLUSTER_NAME \
              --state s3://${BUCKET_NAME} | grep 'is ready' > /dev/null 2>&1;
            if [ $? == 0 ]; then
                break
            else
                echo "cluster ${CLUSTER_NAME} is still provisioning"
            fi
            sleep 30
        done
    else
        echo "Updating cluster ${CLUSTER_NAME}"
        kops update cluster --name ${CLUSTER_NAME}
    fi
}

configureJenkins() {
    # Add jenkins to docker group
    sudo usermod -a -G docker jenkins
    sudo service jenkins restart

    # Enable jenkins to access K8s cluster
    sudo mkdir -p /var/lib/jenkins/.kube
    sudo cp ~/.kube/config /var/lib/jenkins/.kube/
    cd /var/lib/jenkins/.kube/
    sudo chown jenkins:jenkins config
    sudo chmod 750 config
    cd $HOME
}

main() {
    createBucket
    createPublicKey
    createOrUpdateCluster
    configureJenkins
}

main "$@"
