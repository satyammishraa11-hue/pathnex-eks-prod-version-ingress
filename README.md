# Pathnex EKS Infrastructure

Terraform configuration for an Amazon EKS cluster and a set of AWS/Kubernetes
platform components. The repository also contains example Kubernetes
workloads, Services, and Istio ingress routes.

> **Before publishing:** Do not commit `terraform.tfvars`, Terraform state or
> backups, saved plans, AWS credentials, kubeconfig files, or other
> environment-specific data. Start from [`terraform.tfvars.example`](./terraform.tfvars.example)
> and use values for your own AWS account and network.

## What this project provisions

### AWS infrastructure (Terraform)

- An EKS control plane using the Kubernetes version configured in `eks.tf`.
- A managed EC2 node group using Amazon Linux 2023 x86-64 Spot instances,
  with configurable subnet IDs and scaling from 1 to 4 nodes. The configured
  desired size is 3; Terraform ignores later desired-size changes made by the
  autoscaler.
- EKS API access through both public and private endpoints. Public access is
  limited to the CIDRs provided in `api_public_access_cidrs`.
- EKS add-ons: VPC CNI, kube-proxy, CoreDNS, Pod Identity Agent, EBS CSI,
  node monitoring, metrics-server, and ExternalDNS.
- IAM roles, policies, and EKS Pod Identity associations for EBS CSI,
  Cluster Autoscaler, and Karpenter.
- Cluster Autoscaler and Karpenter controller Helm releases.
- KEDA and Istio Helm releases (Istio base, control plane, and ingress
  gateway).
- An encrypted `gp3` EBS StorageClass configured as the default for new PVCs.
  Its reclaim policy is `Delete`.

Core EKS add-on versions are not pinned in Terraform; AWS selects a compatible
version. Helm chart versions are pinned in the configuration.

### Kubernetes examples (apply separately)

The YAML files are examples and are **not** installed by Terraform:

| File | Purpose |
| --- | --- |
| [`nginx.yaml`](./nginx.yaml) | `nginx` namespace, a three-replica NGINX Deployment, and ClusterIP Service. |
| [`apache.yaml`](./apache.yaml) | `apache` namespace, a two-replica Apache Deployment, and ClusterIP Service. |
| [`httpbin.yaml`](./httpbin.yaml) | `httpbin` namespace, a two-replica HTTPBin Deployment, and ClusterIP Service. |
| [`svc-lb.yaml`](./svc-lb.yaml) | Optional LoadBalancer Service for the NGINX workload. |
| [`svc-np.yaml`](./svc-np.yaml) | Optional NodePort Service for NGINX on node port `30080`. |
| [`istio.yaml`](./istio.yaml) | Istio HTTP Gateway and path-based routes for Apache, HTTPBin, and NGINX. |
| [`nginx-istio.yaml`](./nginx-istio.yaml) | `nginx-gitops` namespace plus an Istio route to the GitOps NGINX Service. |
| [`argocd-istio.yaml`](./argocd-istio.yaml) | Istio TLS passthrough route to an Argo CD server already installed in the cluster. |
| [`gitops/nginx/`](./gitops/nginx/) | NGINX Deployment and ClusterIP Service example for a GitOps workflow. |

These manifests require the corresponding namespaces and, for Istio resources,
the Istio CRDs and ingress gateway. The Argo CD route does not install Argo CD.
The LoadBalancer and NodePort Services are alternatives to routing through
Istio; expose workloads only when needed.

## Repository layout

| Path | Description |
| --- | --- |
| `provider.tf` | Terraform/provider constraints and AWS, Kubernetes, and Helm provider configuration. |
| `variables.tf`, `terraform.tfvars.example` | Input variable declarations and safe example values. |
| `eks.tf`, `node_group.tf` | EKS control plane and managed node group. |
| `addons.tf` | EKS add-ons, Helm releases, and Karpenter IAM/controller configuration. |
| `iam.tf` | Pod Identity roles, policies, and associations. |
| `cluster_autoscaler.tf` | Cluster Autoscaler Helm release. |
| `storage.tf` | Default encrypted `gp3` StorageClass. |
| `imports.tf` | Commented examples for importing existing resources; inactive as checked in. |
| `*.yaml`, `gitops/nginx/` | Optional Kubernetes application and Istio examples. |

## Requirements

- Terraform `>= 1.5.0`.
- AWS CLI configured with credentials for the intended AWS account.
- Permissions to manage EKS, EC2, IAM, Auto Scaling, EKS add-ons, and the
  Kubernetes/Helm resources in this configuration.
- Existing IAM roles named `AmazonEKSClusterRole` and `AmazonEKSNodeRole`,
  with the AWS-recommended trust relationships and permissions.
- At least two suitable subnets in the target VPC, preferably private subnets
  in different Availability Zones. Ensure nodes have the required outbound
  access through NAT or appropriate VPC endpoints.
- A trusted public IPv4 CIDR for Kubernetes API access, such as a fixed
  administrator IP with `/32`.
- `kubectl` and Helm for accessing the cluster and applying optional manifests.

The configured node group uses Spot capacity, which can be interrupted.
Karpenter is installed as a controller, but this repository does not define
Karpenter `NodePool`/`EC2NodeClass` resources. Add and review those resources
before expecting Karpenter to provision nodes. Cluster Autoscaler and Karpenter
are both installed; configure their capacity responsibilities deliberately.

## Configure

Create a local variable file from the example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` for your environment:

- `aws_region`: AWS region for the cluster.
- `cluster_name`: EKS cluster name.
- `private_subnet_ids`: subnet IDs for the cluster and managed node group.
- `api_public_access_cidrs`: trusted CIDRs allowed to reach the public EKS API.

The example uses documentation-only placeholder IDs and CIDRs. Replace them
with real values before planning. Do not copy infrastructure IDs or a personal
IP address from another deployment.

## Deploy the infrastructure

From the repository root:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=review.tfplan
terraform show review.tfplan
```

Review the **entire** plan, AWS account, region, resource actions, and network
settings before applying. If the plan is expected:

```bash
terraform apply review.tfplan
```

Saved plans are snapshots: regenerate and review a new plan after changing
configuration or state. Never apply an old `.tfplan` file.

Terraform currently uses local state. State is sensitive and is not suitable
for team collaboration. For shared or production use, configure an encrypted
remote backend with state locking and access controls before deploying.
Confirm that the state matches the real AWS resources before every apply;
do not restore a backup state blindly.

## Connect to the cluster

After the EKS cluster is ready, configure kubeconfig with the same region and
cluster name used in Terraform:

```bash
aws eks update-kubeconfig --region <aws-region> --name <cluster-name>
kubectl get nodes
kubectl get pods --all-namespaces
```

The caller also needs Kubernetes/EKS access. The cluster creator is granted
bootstrap admin access by the configured EKS access settings. Access for
additional identities must be configured separately.

## Apply the example workloads

Apply the app manifests after the cluster and required add-ons are ready:

```bash
kubectl apply -f nginx.yaml
kubectl apply -f apache.yaml
kubectl apply -f httpbin.yaml
```

The Istio charts are installed by Terraform. Apply the Istio routes only after
the gateway and target workloads are available:

```bash
kubectl apply -f istio.yaml
kubectl apply -f nginx-istio.yaml
```

`argocd-istio.yaml` is optional and requires Argo CD to already be installed
in the `argocd` namespace, with TLS enabled on its server Service:

```bash
kubectl apply -f argocd-istio.yaml
```

For the GitOps example, the `nginx-gitops` namespace is created in
`nginx-istio.yaml`. Apply the workload resources from your GitOps controller
or directly with:

```bash
kubectl apply -f gitops/nginx/
```

The `svc-lb.yaml` and `svc-np.yaml` files are optional alternatives for exposing
the NGINX Service; do not apply them unless that exposure is intended.

## Costs, security, and operational notes

- EKS, EC2, EBS, load balancers, public IPv4 addresses, NAT gateways, and
  data transfer may incur charges. Spot pricing and availability vary.
- Keep public API CIDRs narrow and current. Public API access is enabled in
  this configuration; private endpoint access is enabled as well.
- Node SSH access is disabled. Manage nodes through Kubernetes and AWS tooling.
- The default `gp3` StorageClass uses encrypted volumes and `Delete` reclaim
  policy; deleting a PVC may delete its backing volume.
- ExternalDNS IAM permissions for Route 53 are not configured here. Add
  appropriately scoped workload permissions before using it to modify DNS.
- Review IAM policies and AWS networking for your account and requirements.
- Remove optional LoadBalancer/NodePort exposure when it is no longer needed.

To remove Terraform-managed resources, first review the destructive plan:

```bash
terraform plan -destroy
```

Only if you intend to delete the infrastructure, run `terraform destroy` and
review the prompt carefully. Kubernetes resources applied manually or by a
GitOps controller may need separate cleanup.

## Publishing this repository

Before pushing to a public GitHub repository:

1. Keep `terraform.tfvars`, state files/backups, saved plans, kubeconfig, and
   credentials out of Git.
2. Use `terraform.tfvars.example` with placeholder values for documentation.
3. Review the complete diff and staged files, for example with `git status` and
   `git diff --cached`.
4. Do not publish plan files or state JSON; they can contain sensitive
   infrastructure details and values marked sensitive by Terraform.
