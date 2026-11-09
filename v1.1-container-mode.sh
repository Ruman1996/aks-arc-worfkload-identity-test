kubectl create serviceaccount arc-runner -n arc-runners


# arc-runner-rbac.yml

# apiVersion: rbac.authorization.k8s.io/v1
# kind: Role
# metadata:
#   name: arc-runner-container-hooks
#   namespace: arc-runners
# rules:
#   - apiGroups: [""]
#     resources: ["pods"]
#     verbs: ["get", "list", "create", "delete"]

#   - apiGroups: [""]
#     resources: ["pods/exec"]
#     verbs: ["get", "create"]

#   - apiGroups: [""]
#     resources: ["pods/log"]
#     verbs: ["get", "list", "watch"]

#   - apiGroups: [""]
#     resources: ["secrets"]
#     verbs: ["get", "list", "create", "delete"]
# ---
# apiVersion: rbac.authorization.k8s.io/v1
# kind: RoleBinding
# metadata:
#   name: arc-runner-container-hooks
#   namespace: arc-runners
# subjects:
#   - kind: ServiceAccount
#     name: arc-runner
#     namespace: arc-runners
# roleRef:
#   apiGroup: rbac.authorization.k8s.io
#   kind: Role
#   name: arc-runner-container-hooks


# arc-job-pod-template.yaml

# apiVersion: v1
# kind: ConfigMap
# metadata:
#   name: arc-job-pod-template
#   namespace: arc-runners
# data:
#   content: |
#     metadata:
#       labels:
#         azure.workload.identity/use: "true"
#     spec:
#       serviceAccountName: gha-kv-reader


# apply both the ymls  above 

helm get values arc-kv-poc \
  -n arc-runners \
  -o yaml > runner-values-backup.yaml
