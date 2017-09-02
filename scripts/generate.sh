#!/bin/sh
##
# Script to deploy a Kubernetes project with a StatefulSet running a MongoDB Replica Set, to Azure ACS.
##

# Set the location to deploy to - run the following to see list of available locations: $ az account list-locations
LOCATN=uksouth

# Create an Azure resource group (to hold collection of related assets)
echo "Creating Azure group"
az group create --name MongoResourceGroup --location $LOCATN

# Create a new Azure Kubernetes cluster with one Linux master node and just
# one Linux agent node (to keep under free account quote maximum of 4 cores),
echo "Creating ACS Kubernetes orchestrator"
az acs create --orchestrator-type kubernetes --resource-group MongoResourceGroup --name MongoK8sCluster --agent-count 1 --generate-ssh-keys 
echo "Sleeping for 90 seconds before attempting to get credentials"
sleep 90

# Configure kubectl credentials to connect to the new Kubernetes cluster
az acs kubernetes get-credentials --resource-group MongoResourceGroup --name MongoK8sCluster
sleep 2

# Configure host VM using daemonset to disable hugepages
kubectl apply -f ../resources/hostvm-node-configurer-daemonset.yaml
sleep 2

# Register Azure persistent disks to be used by dyanmically created persistent volumes
sed -e "s/LOCATN/${LOCATN}/g" ../resources/azure-storageclass.yaml > /tmp/azure-storageclass.yaml
kubectl apply -f /tmp/azure-storageclass.yaml
rm /tmp/azure-storageclass.yaml
sleep 5

# Create keyfile for the MongoD cluster as a Kubernetes shared secret
TMPFILE=$(mktemp)
/usr/bin/openssl rand -base64 741 > $TMPFILE
kubectl create secret generic shared-bootstrap-data --from-file=internal-auth-mongodb-keyfile=$TMPFILE
rm $TMPFILE

# Create mongodb service with mongod stateful-set
kubectl apply -f ../resources/mongodb-service.yaml
sleep 5

# Print current deployment state (unlikely to be finished yet)
kubectl get all 
kubectl get persistentvolumes
echo
echo "Keep running the following command until all 'mongod-n' pods are shown as running:  kubectl get all"
echo

