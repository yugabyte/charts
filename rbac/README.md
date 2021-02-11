## RBAC resources for Yugabyte Platform

This directory contains different RBAC manifests containing Roles,
RoleBindings etc required to create YugabyteDB universes using
Yugabyte Platform.

### 0. yugabyte-platform-universe-management-sa.yaml (required)
This is the ServiceAccount whose secret can be used to generate a
kubeconfig. This should ideally be created in a namespace where your
are going to install the platform software. It can be created in any
other namespace as well, it should not be deleted once it is being
used by the platform.

Make sure you replace the `[yb-platform]` from the following command
with correct namespace for the ServiceAccount.

```console
kubectl create ns [yb-platform]
kubectl apply -n [yb-platform] -f yugabyte-platform-universe-management-sa.yaml
```

Once the ServiceAccount is created, you can follow any one of the
following steps depending to your requirements.

### a. platform-global.yaml
Grants access to only the specific cluster roles to create and manage
YugabyteDB universes across all the namespaces in a cluster. Contains
ClusterRoles and ClusterRoleBindings for the required set of
permissions.

Make sure you replace the `[yb-platform]` from the following command
with correct namespace of the ServiceAccount (from the step 0).

```console
cat platform-global.yaml \
  | sed "s/namespace: <SA_NAMESPACE>/namespace: [yb-platform]"/g \
  | kubectl apply -f -
```

### b. platform-global-admin.yaml
Grants broad cluster level admin access.

Make sure you replace the `[yb-platform]` from the following command
with correct namespace of the ServiceAccount (from the step 0).

```console
cat platform-global-admin.yaml \
  | sed "s/namespace: <SA_NAMESPACE>/namespace: [yb-platform]"/g \
  | kubectl apply -f -
```

### c. platform-namespaced.yaml
Grants access to only the specific roles required to create and manage
YugabyteDB universes in a particular namespace only. Contains Roles
and RoleBindings for the required set of permissions.

Example: You want to allow platform software to manage YugabyteDB
universes in the namespaces `yb-db-trial` and `yb-db-us-east4-a` (the
target namespaces). In this case you will apply
`platform-namespaced.yaml` in both the target namespaces.

- Make sure you replace the `[yb-platform]` from the following command
  with correct namespace of the ServiceAccount (from the step 0).
- Specify the target namespace using `-n`. i.e. replace
  `[yb-db-trial]` with correct value.

```console
cat platform-namespaced.yaml \
  | sed "s/namespace: <SA_NAMESPACE>/namespace: [yb-platform]"/g \
  | kubectl apply -n [yb-db-trial] -f -
```

### d. platform-namespaced-admin.yaml
Grants namespace level admin access.

Similar to (c), if you have multiple target namespaces, then you will
have to apply the YAML mulitple times in those target namespaces.

- Make sure you replace the `[yb-platform]` from the following command
  with correct namespace of the ServiceAccount (from the step 0).
- Specify the target namespace using `-n`. i.e. replace
  `[yb-db-trial]` with correct value.

```console
cat platform-namespaced-admin.yaml \
  | sed "s/namespace: <SA_NAMESPACE>/namespace: [yb-platform]"/g \
  | kubectl apply -n [yb-db-trial] -f -
```
