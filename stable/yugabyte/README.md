# YugabyteDB using Helm Charts

This page has details on deploying YugabyteDB on [Kubernetes](https://kubernetes.io) using [Helm Charts](https://github.com/kubernetes/charts). c

## Requirements
### Install Helm: 2.8+
You can install helm by following [these instructions](https://github.com/kubernetes/helm#install).
You can check the version of helm installed using the following command:
```
helm version
Client: &version.Version{SemVer:"v2.9.1", GitCommit:"20adb27c7c5868466912eebdf6664e7390ebe710", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.9.1", GitCommit:"20adb27c7c5868466912eebdf6664e7390ebe710", GitTreeState:"clean"}
```

## Create Kubernetes clusters and node pools created
In order for you to install YugabyteDB using helm you need have a kubernetes cluster created and make sure it has node pools created as well.

#### Creating new cluster
If not already created, you can create a new kubernetes cluster by running the below command:
```
gcloud container clusters create yugabyte-demo --zone us-west1-b --machine-type=n1-standard-8
```

#### Update the local credentials
Fetch the credentials for the newly created kubernetes cluster by running the below command:
```
gcloud container clusters get-credentials yugabyte-demo --zone us-west1-b
```

## Deploying YugabyteDB using Helm Charts

### Creating YugabyteDB RBAC on your kubernetes cluster
In order to install helm package you need to have a service account with certain cluster role binding, if you don't already have such service account
you can run the yugabyte-rbac.yaml to create a service account.
```
kubectl create -f yugabyte-rbac.yaml
```

### Initiatlizing helm and tiller on your kubernetes cluster
If you ran the yugabyte-rbac.yaml script above, your service account name would be `yugabyte-helm` if not make a note of the service account with necessary
helm privileges and initialize helm/tiller with that service account
```
helm init --service-account yugabyte-helm --upgrade --wait
```

### Installing YugabyteDB helm package on your kubernetes cluster
If the helm init was successful then you can go ahead and run the helm install command to install the yugabyte helm chart, this would go with default resources and replication of 3.
```
helm install yugabyte --namespace yb-demo --name yb-demo --wait
```

### Overriding YugabyteDB helm package with custom resources
If you want to override the default resources for the yugabyte pods, you could do so using helm

#### Creating YugabyteDB cluster with 5 nodes
```
helm install yugabyte --set replicas.tserver=5 --namespace yb-demo --name yb-demo --wait
```

#### Creating YugabyteDB cluster with custom resource
```
helm install yugabyte --set resource.tserver.requests.cpu=8,resource.tserver.requests.memory=15Gi --namespace yb-demo --name yb-demo
```

#### Creating YugabyteDB cluster with resource upper limits
```
helm install yugabyte --set resource.tserver.limits.cpu=16,resource.tserver.limits.memory=30Gi --namespace yb-demo --name yb-demo --wait
```

#### Creating YugabyteDB cluster with YCQL authentication enabled.
```
helm install yugabyte --set gflags.tserver.use_cassandra_authentication=true --namespace yb-demo --name yb-demo --wait
```

#### Create YugabyteDB cluster with larger disk.
The default helm chart brings up a YugabyteDB with 10Gi for master nodes and 10Gi for tserver nodes. You override those defaults as below.
```
helm install yugabyte --set storage.tserver.size=100Gi --namespace yb-demo --name yb-demo --wait
```

#### Create YugabyteDB cluster with different storage class.
```
helm install yugabyte --set storage.tserver.storageClass=custom-storage,storage.master.storageClass=custom-storage --namespace yb-demo --name yb-demo --wait
```

### Exposing YugabyteDB service endpoints using LoadBalancer
By default YugabyteDB helm would expose all the API services via a shared LoadBalancer on the yb-tserver as well as the master ui service via another LoadBalancer. If you wish to expose ysql, ycql, yedis services via independent LoadBalancers for your app to use, do the following.

#### Exposing individual service endpoint
If you want individual LoadBalancer endpoint for each of the services (YSQL, YCQL, YEDIS), run the following command
```
helm install yugabyte -f expose-all.yaml --namespace yb-demo --name yb-demo --wait
```

#### Enable TLS for YugabyteDB (Note: This is only available for Yugabyte Platform)
The assumption here is you already have the pull secret installed to pull from our private Yugabyte Platform registry
YugabyteDB has three gflags that help build the level on encryption you need,
Following two flags applies to both master and tserver
`use_node_to_node_encryption` whether or not you would want to enable node to node encryption
`allow_insecure_connections` whether or not you would want to have insecure connections allowed when tls is enabled

Following flag only applies to tserver
`use_client_to_server_encryption` whether or not you would want to enable client to node encryption, node enabling this
would mean your apps should have the certificate to talk to the database.

```
helm install yugabyte --namespace yb-demo --name yb-demo --set=tls.enabled=true,Image.repository=quay.io/yugabyte/yugabyte,gflags.master.use_node_to_node_encryption=true,gflags.tserver.use_node_to_node_encryption=true,gflags.master.allow_insecure_connections=false,gflags.tserver.allow_insecure_connections=false,Image.pullSecretName=yugabyte-k8s-pull-secret --wait
```
Follow the instructions on the NOTES section.
