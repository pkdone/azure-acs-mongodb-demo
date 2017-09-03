# MongoDB Deployment Demo for Kubernetes on Azure ACS

An example project demonstrating the deployment of a MongoDB Replica Set via Kubernetes on Azure Container Services (ACS). Contains example Kubernetes YAML resource files (in the 'resource' folder) and associated Kubernetes based Bash scripts (in the 'scripts' folder) to configure the environment and deploy a MongoDB Replica Set.

For further background information on what these scripts and resource files do, plus general information about running MongoDB with Kubernetes, see: [http://k8smongodb.net/](http://k8smongodb.net/)


## 1 How To Run

### 1.1 Prerequisites

Ensure the following dependencies are already fulfilled on your host Linux/Windows/Mac Workstation/Laptop:

1. An account has been registered with Microsoft Azure. You can sign up to a [free trial](https://azure.microsoft.com/free) for Azure. Note: The free trial places some restrictions on account resource quotas, in particular, restricting the total number of CPU cores that can be provisioned, to 4.
2. Azures’s client command line tool [az](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) has been installed. 
3. Your local workstation has the Kubernetes command tool (“kubectl”) installed and the 'az' tool is authenticated to access the appropriate Azure account:

    ```
    $ az acs kubernetes install-cli
    $ az login   (when prompted, follow the instructions to sign in via a browser, to authenticate the CLI)
    ```

### 1.2 Main Deployment Steps 

1. To create a Kubernetes cluster and deploy the MongoDB Service (including the StatefulSet running "mongod" containers), via a command-line terminal/shell, execute the following:

    ```
    $ cd scripts
    $ ./generate.sh
    ```

2. Re-run the following command, until all 3 “mongod” pods (and their containers) have been successfully started (“Status=Running”; usually takes a minute or two).

    ```
    $ kubectl get all
    ```

3. Execute the following script which connects to the first Mongod instance running in a container of the Kubernetes StatefulSet, via the Mongo Shell, to (1) initialise the MongoDB Replica Set, and (2) create a MongoDB admin user (specify the password you want as the argument to the script, replacing 'abc123').

    ```
    $ ./configure_repset_auth.sh abc123
    ```

You should now have a MongoDB Replica Set initialised, secured and running in a Kubernetes Stateful Set.

You can also view the the state of the deployed environment via the [Microsoft Azure Dashboard](https://portal.azure.com).

**Note:** To specify an alternative Azure location to deploy to (rather than "uksouth"), change the value of the variable "LOCATN" at the top of the file "generate.sh". You can first view the list of available locations by running the command: `$ az account list-locations`


### 1.3 Example Tests To Run To Check Things Are Working

Use this section to prove:

1. Data is being replicated between members of the containerised replica set.
2. Data is retained even when the MongoDB Service/StatefulSet is removed and then re-created (by virtue of re-using the same Persistent Volume Claims).

#### 1.3.1 Replication Test

Connect to the container running the first "mongod" replica, then use the Mongo Shell to authenticate and add some test data to a database:

    $ kubectl exec -it mongod-0 -c mongod-container bash
    $ mongo
    > db.getSiblingDB('admin').auth("main_admin", "abc123");
    > use test;
    > db.testcoll.insert({a:1});
    > db.testcoll.insert({b:2});
    > db.testcoll.find();
    
Exit out of the shell and exit out of the first container (“mongod-0”). Then connect to the second container (“mongod-1”), run the Mongo Shell again and see if the previously inserted data is visible to the second "mongod" replica:

    $ kubectl exec -it mongod-1 -c mongod-container bash
    $ mongo
    > db.getSiblingDB('admin').auth("main_admin", "abc123");
    > db.setSlaveOk(1);
    > use test;
    > db.testcoll.find();
    
You should see that the two records inserted via the first replica, are visible to the second replica.

#### 1.3.2 Redeployment Without Data Loss Test

To see if Persistent Volume Claims really are working, run a script to drop the Service & StatefulSet (thus stopping the pods and their “mongod” containers) and then a script to re-create them again:

    $ ./delete_service.sh
    $ ./recreate_service.sh
    $ kubectl get all
    
As before, keep re-running the last command above, until you can see that all 3 “mongod” pods and their containers have been successfully started again. Then connect to the first container, run the Mongo Shell and query to see if the data we’d inserted into the old containerised replica-set is still present in the re-instantiated replica set:

    $ kubectl exec -it mongod-0 -c mongod-container bash
    $ mongo
    > db.getSiblingDB('admin').auth("main_admin", "abc123");
    > use test;
    > db.testcoll.find();
    
You should see that the two records inserted earlier, are still present.

### 1.4 Undeploying & Cleaning Down the Kubernetes Environment

**Important:** This step is required to ensure you aren't continuously charged by Microsoft Azure for an environment you no longer need.

Run the following script to undeploy the MongoDB Service & StatefulSet plus related Kubernetes resources, followed by the removal of the ACS Kubernetes cluster.

    $ ./teardown.sh
    
It is also worth checking in the [Microsoft Azure Dashboard](https://portal.azure.com), to ensure all resources have been removed correctly.


## 2 Project Details

### 2.1 Factors Addressed By This Project

* Deployment of a MongoDB on ACS's Kubernetes platform
* Use of Kubernetes StatefulSets and PersistentVolumeClaims to ensure data is not lost when containers are recycled
* Proper configuration of a MongoDB Replica Set for full resiliency
* Securing MongoDB by default for new deployments
* Disabling Transparent Huge Pages to improve performance
* Disabling NUMA to improve performance
* Controlling CPU & RAM Resource Allocation
* Correctly configuring WiredTiger Cache Size in containers
* Controlling Anti-Affinity for Mongod Replicas to avoid a Single Point of Failure

### 2.2 Factors To Be Potentially Addressed In The Future By This Project

* Leveraging XFS filesystem for data file storage to improve performance. _The ability for dynamically provisioned PersistentVolumes to define the "fstype" field, to declare that "XFS" should be used, is [not scheduled to be supported until Kubernetes version 1.8](https://github.com/kubernetes/kubernetes/pull/45345). An alternative approach would be to first create provider specific storage disks based on XFS directly, and then explicitly declare PersistentVolumes based on this storage. However, for Azure/ACS, currently [Virtual Hard Drive (VHD) Blobs](https://docs.microsoft.com/en-us/azure/virtual-machines/scripts/virtual-machines-linux-cli-sample-create-vm-vhd) must be created for this, which requires generating and uploading, from the client, large blog images (eg. 3 x 10GB images) as part of the deployment process. For demo purposes, this is way too cumbersome and time-consuming. As a result this project does not cater for ensuring that the underlying storage for Mongod containers, is XFS based._

