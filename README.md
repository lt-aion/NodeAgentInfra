# Infrastructure Deployment

## Structure

```
infra/
├── kind-cluster.yaml         # Kind cluster configuration (Maps 9001/9002)
├── charts/
│   ├── genapp/               # Generic application chart
├── environments/
│   └── demo/
│       ├── authn.yaml        # Authn service values
│       ├── task.yaml         # Task service values
└── README.md
```

---

## Quick Start

### Prerequisites
- Docker installed and running
- `kind` installed
- `kubectl` installed
- `helm` installed

**Quick Install:**
You can use the provided script to install all prerequisites (Linux):
```bash
./scripts/install-prereqs.sh
```

---

## Commands



### 1. Initialize Cluster (First Time Setup)

```bash
# Create Kind cluster with port mapping (9001->30001, 9002->30002)
kind create cluster --name aion-cluster --config kind-cluster.yaml
```

### 2. Load Images (Required for Private ECR)

Since these images are in a private ECR registry, you must pull them locally and load them into Kind:

```bash
# Pull images
docker pull 056562102950.dkr.ecr.ap-south-1.amazonaws.com/aion/nodeagent-authn-svc:latest
docker pull 056562102950.dkr.ecr.ap-south-1.amazonaws.com/aion/nodeagent-task-svc:latest

# Load into Kind
kind load docker-image 056562102950.dkr.ecr.ap-south-1.amazonaws.com/aion/nodeagent-authn-svc:latest --name aion-cluster
kind load docker-image 056562102950.dkr.ecr.ap-south-1.amazonaws.com/aion/nodeagent-task-svc:latest --name aion-cluster
```

### 3. Deploy Applications

```bash
# Deploy Authn Service
helm upgrade --install authn ./charts/genapp/0.1.0 \
  -f environments/demo/authn.yaml --create-namespace

# Deploy Task Service
helm upgrade --install task ./charts/genapp/0.1.0 \
  -f environments/demo/task.yaml --create-namespace
```

---

## Access

Services are exposed directly on localhost ports via NodePort mapping.

| Service | Local URL | NodePort |
|---------|-----------|----------|
| Authn   | `http://localhost:9001` | 30001 |
| Task    | `http://localhost:9002` | 30002 |

> **Note:** The Kind configuration maps localhost:9001 → NodePort:30001 (and 9002 → 30002)

---

## Cleanup Commands

### Remove Applications
```bash
helm uninstall authn
helm uninstall task
```

### Destroy Entire Cluster
```bash
kind delete cluster --name aion-cluster
```

---

### Check Pod Status
```bash
kubectl get pods -A
```

### View Pod Logs
```bash
kubectl logs -f deployment/authn-svc
kubectl logs -f deployment/task-svc
```

### References

- For setting up headless sso: https://docs.aws.amazon.com/cli/latest/reference/sso/login.html
- For docker image pull ecr auth: https://stackoverflow.com/a/73332364