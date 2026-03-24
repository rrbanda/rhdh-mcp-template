# FastMCP Server Template - Demo Runbook

## Architecture

```
Developer -> RHDH Template -> Creates 2 GitHub Repos
                                  |
                    +-------------+-------------+
                    |                           |
              App Repo                    GitOps Repo
           (source code)           (Kustomize manifests)
                    |                           |
                    v                           v
            Tekton CI Pipeline           ArgoCD watches
          (clone -> build-push ->        (auto-sync to
           clone-gitops ->                OpenShift)
           push-gitops)                     |
                    |                       v
                    +----> Updates    Deployment/Service/Route
                           image tag    on OpenShift
                           in GitOps
                           repo
```

**Flow:**
1. Developer runs the RHDH template, providing a service name
2. Template creates an **app repo** (code, Dockerfile, devfile, catalog-info) and a **GitOps repo** (Kustomize manifests)
3. Template configures a GitHub webhook on the app repo pointing to the Tekton EventListener
4. Template creates an ArgoCD Application watching the GitOps repo
5. Template registers both repos as entities in the RHDH catalog
6. On git push to the app repo: Tekton CI builds the image, then updates the image tag in the GitOps repo
7. ArgoCD detects the GitOps change and rolls out the new Deployment

## Cluster URLs

| Service | URL |
|---------|-----|
| RHDH | https://backstage-developer-hub-rhdh-operator.apps.ocp.v7hjl.sandbox2288.opentlc.com |
| ArgoCD | https://openshift-gitops-server-openshift-gitops.apps.ocp.v7hjl.sandbox2288.opentlc.com |
| Dev Spaces | https://devspaces.apps.ocp.v7hjl.sandbox2288.opentlc.com |
| EventListener | https://el-fastmcp-listener-mcp-servers.apps.ocp.v7hjl.sandbox2288.opentlc.com |
| OpenShift API | https://api.ocp.v7hjl.sandbox2288.opentlc.com:6443 |

## Prerequisites (Cluster Resources)

### Namespaces

| Namespace | Purpose |
|-----------|---------|
| `rhdh-operator` | RHDH deployment and configuration |
| `mcp-servers` | Target namespace for deployed MCP servers |
| `openshift-gitops` | ArgoCD / OpenShift GitOps |
| `openshift-devspaces` | Dev Spaces |
| `openshift-pipelines` | Tekton Pipelines operator |

The `mcp-servers` namespace must have the label:
```
argocd.argoproj.io/managed-by=openshift-gitops
```

### Tekton Resources (namespace: `mcp-servers`)

| Resource | Name | Purpose |
|----------|------|---------|
| Pipeline | `fastmcp-ci` | CI pipeline: clone, build-push, clone-gitops, push-gitops |
| TriggerTemplate | `fastmcp-deploy-template` | Creates PipelineRun from webhook payload |
| TriggerBinding | `github-push-binding` | Extracts git-url, git-revision, repo-name from GitHub webhook |
| EventListener | `fastmcp-listener` | Receives GitHub webhooks, filters for `refs/heads/main` |

### Secrets

| Secret | Namespace | Purpose |
|--------|-----------|---------|
| `rhdh-secrets` | `rhdh-operator` | RHDH config: GitHub token, ArgoCD token, K8s SA token, Keycloak creds |
| `github-pat-secret` | `mcp-servers` | GitHub PAT for Tekton git-clone (basic-auth type) |
| `github-basic-auth` | `mcp-servers` | Git credentials for Tekton git-cli push (.git-credentials format) |
| `github-webhook-secret` | `mcp-servers` | Webhook secret for EventListener GitHub interceptor |
| `github-repo-creds` | `openshift-gitops` | GitHub credentials for ArgoCD to access repos |

### ArgoCD Configuration (namespace: `openshift-gitops`)

The `openshift-gitops` ArgoCD CR has:
- **Account**: `rhdh` with `apiKey` capability (`spec.extraConfig`)
- **RBAC**: `role:rhdh` with full permissions on applications, projects, repositories, clusters

### RBAC (cluster-scoped)

| Resource | Name | Purpose |
|----------|------|---------|
| ClusterRole | `backstage-k8s-reader` | Read access to pods, deployments, tekton, routes, ArgoCD apps, checlusters |
| ClusterRoleBinding | `backstage-k8s-reader-binding` | Binds above role to `backstage-k8s-plugin` SA in `rhdh-operator` |
| ServiceAccount | `backstage-k8s-plugin` | SA used by RHDH Kubernetes plugin (token stored in `rhdh-secrets`) |

### RHDH Dynamic Plugins

| Plugin | Purpose |
|--------|---------|
| `backstage-plugin-kubernetes-backend-dynamic` | Kubernetes backend - fetches pods, deployments |
| `backstage-plugin-kubernetes` | Kubernetes frontend - displays resources |
| `backstage-community-plugin-tekton` | CI tab - shows PipelineRuns |
| `backstage-community-plugin-topology` | Topology tab - visual deployment graph |
| `backstage-community-plugin-argocd-backend` | ArgoCD backend - fetches app status |
| `backstage-community-plugin-argocd` | CD tab + Overview card - ArgoCD deployment lifecycle |
| `roadiehq-scaffolder-backend-argocd` | Scaffolder action `argocd:create-resources` |
| `backstage-plugin-scaffolder-backend-module-github-dynamic` | GitHub scaffolder actions (publish, webhook) |
| `backstage-community-plugin-catalog-backend-module-keycloak-dynamic` | Keycloak user/group sync |

### Plugin Mount Points

| Tab | Plugin | Mount Point |
|-----|--------|------------|
| CI | Tekton | `entity.page.ci/cards` |
| CD | ArgoCD Lifecycle | `entity.page.cd/cards` |
| Topology | Topology | `entity.page.topology/cards` |
| Overview | ArgoCD Summary | `entity.page.overview/cards` |
| Kubernetes | Kubernetes | `entity.page.kubernetes/cards` |

## Demo Script

### Before the Demo

1. **Verify cluster health:**
   ```bash
   oc get pods -n rhdh-operator | grep backstage
   oc get pods -n openshift-devspaces
   oc get application.argoproj.io -n openshift-gitops | grep -E 'mcp|lol'
   ```

2. **Clean up previous demo runs** (if re-running):
   ```bash
   # Delete repos on GitHub
   PAT="<your-github-pat>"
   curl -X DELETE "https://api.github.com/repos/rrbanda/<name>" -H "Authorization: token $PAT"
   curl -X DELETE "https://api.github.com/repos/rrbanda/<name>-gitops" -H "Authorization: token $PAT"

   # Delete ArgoCD app
   oc delete application.argoproj.io <name> -n openshift-gitops

   # Delete deployed resources
   oc delete deployment,service,route -l app=<name> -n mcp-servers

   # Delete pipeline runs
   oc delete pipelinerun -l backstage.io/kubernetes-id=<name> -n mcp-servers

   # Unregister from RHDH catalog (via UI: Catalog -> entity -> kebab menu -> Unregister)
   ```

### During the Demo

**Step 1: Show the Template (2 min)**
- Open RHDH -> Create -> "FastMCP Server"
- Walk through the 3 parameter pages (Service Details, API Config, Deployment)
- Point out: "This creates everything -- repos, CI pipeline, GitOps, ArgoCD, catalog registration"

**Step 2: Run the Template (1 min)**
- Fill in: name=`demo-mcp`, owner=`platform-engineering`, defaults for the rest
- Repo: github.com / rrbanda / demo-mcp
- Click Create and wait for all 8 steps to complete

**Step 3: Show Created Repos (1 min)**
- Click "Application Repository" -- show code, Dockerfile, devfile.yaml, catalog-info.yaml
- Click "GitOps Repository" -- show manifests/base/ with deployment, service, route, kustomization

**Step 4: Show RHDH Entity (3 min)**
- Click "View in Catalog"
- **Overview tab**: ArgoCD deployment summary card
- **Topology tab**: Visual deployment topology
- **CI tab**: Pipeline runs (will show the initial build triggered by webhook)
- **CD tab**: ArgoCD deployment lifecycle (Synced/Healthy)
- **Kubernetes tab**: Live pod status

**Step 5: Show Dev Spaces (2 min)**
- Click "Open in Dev Spaces" link from Overview
- Show the workspace opening with code cloned
- Point out: devfile.yaml configured endpoints, commands

**Step 6: Show GitOps Flow (3 min)**
- Make a small code change in the app repo (via Dev Spaces or GitHub UI)
- Push to main
- Switch to CI tab -- show new pipeline run in progress (clone -> build -> clone-gitops -> push-gitops)
- Switch to CD tab -- show ArgoCD picking up the new image
- "No kubectl, no manual deployment -- pure GitOps"

### Talking Points

- **Golden Path**: Developers get a production-ready setup in 60 seconds
- **Separation of Concerns**: App code and deployment config in separate repos
- **GitOps**: Git is the single source of truth; ArgoCD handles drift detection
- **CI/CD Split**: Tekton does CI (build), ArgoCD does CD (deploy) -- no direct cluster writes from CI
- **Inner Loop**: Dev Spaces provides a cloud IDE with the same runtime environment
- **Visibility**: RHDH gives a single pane of glass -- CI, CD, topology, Kubernetes

## Troubleshooting

### Template fails at "Create ArgoCD Application"
**Error**: `permission denied: projects, create`
**Fix**: Patch ArgoCD RBAC:
```bash
oc patch argocd openshift-gitops -n openshift-gitops --type merge -p '{
  "spec": {"rbac": {"policy": "g, system:cluster-admins, role:admin\np, role:rhdh, applications, *, */*, allow\np, role:rhdh, clusters, get, *, allow\np, role:rhdh, repositories, *, *, allow\np, role:rhdh, projects, *, *, allow\ng, rhdh, role:rhdh"}}
}'
```

### CI pipeline push-gitops fails with "protected branch"
**Error**: `GH006: Protected branch update failed`
**Fix**: Remove branch protection on the GitOps repo:
```bash
curl -X DELETE "https://api.github.com/repos/rrbanda/<name>-gitops/branches/main/protection" \
  -H "Authorization: token $PAT"
```

### CI pipeline push-gitops fails with "src refspec main does not match"
**Error**: Detached HEAD after git-clone
**Fix**: Pipeline uses `git checkout -b main` and `git push origin HEAD:main` (already fixed in current pipeline)

### Topology tab shows "No resources found"
**Cause**: `backstage.io/kubernetes-id` label mismatch between catalog entity and deployed resources
**Fix**: Ensure the Deployment has label `backstage.io/kubernetes-id: <entity-name>` matching the catalog-info.yaml annotation

### ArgoCD app stuck in "Progressing"
**Cause**: Image can't be pulled (no CI build yet)
**Fix**: Trigger a manual pipeline run:
```bash
cat <<'EOF' | oc create -f -
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: <name>-run-
  namespace: mcp-servers
  labels:
    app: <name>
    backstage.io/kubernetes-id: <name>
    tekton.dev/pipeline: fastmcp-ci
spec:
  pipelineRef:
    name: fastmcp-ci
  params:
    - name: git-url
      value: https://github.com/rrbanda/<name>.git
    - name: git-revision
      value: main
    - name: repo-name
      value: <name>
    - name: deploy-namespace
      value: mcp-servers
    - name: gitops-repo-url
      value: https://github.com/rrbanda/<name>-gitops.git
  workspaces:
    - name: source
      volumeClaimTemplate:
        spec:
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 1Gi
    - name: gitops
      volumeClaimTemplate:
        spec:
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 256Mi
    - name: git-credentials
      secret:
        secretName: github-basic-auth
EOF
```

### Dev Spaces shows empty workspace
**Cause**: Missing `devfile.yaml` in the repo, or repo is private without OAuth
**Fix**: Repos are created as public. Verify `devfile.yaml` exists in the app repo.

### GitHub token expired
**Symptoms**: Template fails at repo creation, or CI can't clone
**Fix**: Generate a new GitHub PAT and update secrets:
```bash
# Update Tekton secrets
oc delete secret github-pat-secret github-basic-auth -n mcp-servers
oc create secret generic github-pat-secret --type=kubernetes.io/basic-auth \
  --from-literal=username=rrbanda --from-literal=password=<NEW_PAT> -n mcp-servers
oc annotate secret github-pat-secret tekton.dev/git-0=https://github.com -n mcp-servers

oc create secret generic github-basic-auth -n mcp-servers \
  --from-literal=.gitconfig='[credential "https://github.com"]
    helper = store' \
  --from-literal=.git-credentials="https://rrbanda:<NEW_PAT>@github.com"

# Update RHDH secret
oc patch secret rhdh-secrets -n rhdh-operator -p "{\"stringData\":{\"GITHUB_TOKEN\":\"<NEW_PAT>\"}}"

# Update ArgoCD repo creds
oc patch secret github-repo-creds -n openshift-gitops -p "{\"stringData\":{\"password\":\"<NEW_PAT>\"}}"

# Restart RHDH to pick up the new token
oc rollout restart deployment backstage-developer-hub -n rhdh-operator
```

## Full Cleanup (Remove a Scaffolded Project)

Replace `<name>` with the service name (e.g., `demo-mcp`):

```bash
PAT="<your-github-pat>"
NAME="<name>"

# 1. Delete GitHub repos
curl -X DELETE "https://api.github.com/repos/rrbanda/${NAME}" -H "Authorization: token $PAT"
curl -X DELETE "https://api.github.com/repos/rrbanda/${NAME}-gitops" -H "Authorization: token $PAT"

# 2. Delete ArgoCD application
oc delete application.argoproj.io ${NAME} -n openshift-gitops

# 3. Delete OpenShift resources
oc delete deployment,service,route -l app=${NAME} -n mcp-servers

# 4. Delete pipeline runs
oc delete pipelinerun -l backstage.io/kubernetes-id=${NAME} -n mcp-servers

# 5. Delete container image
oc delete imagestream ${NAME} -n mcp-servers 2>/dev/null || true

# 6. Unregister from RHDH (via UI or API)
# UI: Catalog -> find entity -> three-dot menu -> Unregister entity
```
