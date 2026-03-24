# Demo: Self-Service MCP Servers with AI-Powered Development on OpenShift

**Duration:** 7 minutes | **Format:** Tell-Show-Tell

---

## Opening — The Problem (30 seconds)

> "Developers today want to expose their APIs as tools that AI agents can use — that's what MCP servers do. But setting up the infrastructure — repos, CI/CD pipelines, GitOps, cloud IDEs — takes days of boilerplate. And when you add AI coding assistants, most organizations can't use cloud-hosted ones because the code can't leave the network.
>
> We solved both problems. Let me show you how a developer goes from zero to a running MCP server with an on-prem AI coding agent — in minutes, not days."

---

## Act 1 — The Template (1.5 minutes)

### TELL (15 seconds)

> "Everything starts in Red Hat Developer Hub — our internal developer portal. We've created a golden-path template that gives developers everything they need."

### SHOW

Open RHDH, navigate to **Create > FastMCP Server**.

> "The developer fills in three things: a name, the API they want to wrap, and where to deploy."

Fill in the form — name: `demo-mcp`, leave defaults, click through to the **Review page**. **STOP here.**

> "On the review page you can see what's about to happen — it creates two GitHub repos, one for code and one for GitOps manifests, wires up a Tekton CI pipeline, creates an ArgoCD application for continuous deployment, and registers everything in the catalog. Rather than wait, let me show you one that's already running."

### TELL (10 seconds)

> "So with one click, the platform gives the developer a production-ready setup — proper CI/CD separation, GitOps, and full visibility in the portal. No tickets, no waiting."

---

## Act 2 — The Running Service (1.5 minutes)

### TELL (10 seconds)

> "Let's look at what the developer gets after the template runs."

### SHOW

Navigate to **Catalog > type-a-cmp-mcp**.

> "Here's the component in our catalog. Everything about this service is visible in one place."

**Click CI tab**

> "Under CI — Tekton pipeline runs. Every git push triggers a build. It clones the code, builds a container image, and updates the GitOps repo with the new image tag. Pure CI — no deployment logic here."

**Click CD tab**

> "Under CD — ArgoCD watches the GitOps repo and syncs changes to OpenShift automatically. Right now it's synced and healthy."

**Click Topology tab**

> "Topology shows the live deployment — pod running, service, route — all created automatically by ArgoCD."

### TELL (10 seconds)

> "So the developer has full visibility into their CI pipeline, their deployment status, and their running infrastructure — all from the portal. But the real power is what happens when they click this link."

---

## Act 3 — The On-Prem AI Coding Agent (3 minutes)

### TELL (15 seconds)

> "Here's where it gets interesting. The template didn't just give the developer repos and pipelines — it gave them a cloud IDE with an on-prem AI coding agent baked in. The agent runs against our own LLM on the cluster. Code never leaves the network."

### SHOW

Click **"Open in Dev Spaces"** on the Overview page.

> "This opens Dev Spaces — VS Code in the browser. The workspace comes pre-configured with Goose, an open-source AI coding agent by Block, connected to our on-prem 120-billion parameter model served by vLLM through Llama Stack."

Wait for workspace to load (it should be pre-started). Open terminal.

> "No setup needed — the proxy, the model connection, git credentials — everything was configured automatically by the template."

**Run:**

```bash
goose run --no-session --text "what can you do for me"
```

> "Goose already understands this project. It read the `.goosehints` file that the template included, so it knows this is a FastMCP server, what tools exist, how to add new ones, and the coding patterns to follow."

Wait for response, then point out capabilities.

> "Now let me show the real power — agent skills. These are reusable recipes that encode your team's best practices."

**Run:**

```bash
goose run --no-session --text "Add a new @mcp.tool called delete_item that calls DELETE /items/{item_id} and returns the result"
```

> "Watch — Goose reads the existing code, understands the patterns, and writes a new MCP tool that follows the exact same conventions. It uses the shared HTTP helper, adds proper type hints, writes the docstring that LLMs need to know when to call this tool."

Wait for response. Show the generated code briefly.

### TELL (15 seconds)

> "The key point: this entire AI workflow is on-prem. The model is served by vLLM on OpenShift AI, accessed through Llama Stack as a unified AI runtime. The developer's code never leaves the cluster. And because it's a recipe, every developer on the team gets the same quality — it's not dependent on individual prompt engineering skills."

---

## Act 4 — The Inner Loop (30 seconds)

### TELL

> "And when the developer is ready, they commit and push right from Dev Spaces. That triggers the full pipeline we saw earlier — Tekton builds the image, updates the GitOps repo, ArgoCD syncs, and the new MCP tool is live on OpenShift. The entire inner development loop stays in the browser."

*(No need to actually push — just describe it.)*

---

## Closing (30 seconds)

> "To recap — one template gives the developer everything:
>
> - Two repos with proper GitOps separation
> - Tekton CI and ArgoCD CD — fully automated
> - A cloud IDE with an on-prem AI coding agent
> - Agent skills that encode team best practices
> - Full visibility in the developer portal
>
> The platform team defines the golden path once. Every developer gets a consistent, production-ready, AI-powered setup from day one — and the code never leaves the network."

---

## Pre-Demo Checklist

| Item | Action |
|------|--------|
| `type-a-cmp-mcp` workspace | Pre-start 5 min before demo so it loads instantly |
| RHDH tab | Open to catalog page |
| `type-a-cmp-mcp` component | Open in a second tab (CI/CD/Topology ready to click) |
| Template page | Open Create page with FastMCP template ready |
| ArgoCD (optional) | Open `type-a-cmp-mcp` app page as backup visual |

---

## Key URLs

| Resource | URL |
|----------|-----|
| RHDH Portal | `https://backstage-developer-hub-rhdh-operator.apps.ocp.v7hjl.sandbox2288.opentlc.com` |
| Dev Spaces | `https://devspaces.apps.ocp.v7hjl.sandbox2288.opentlc.com` |
| ArgoCD | `https://openshift-gitops-server-openshift-gitops.apps.ocp.v7hjl.sandbox2288.opentlc.com` |
| Llama Stack | `https://llamastack-llamastack.apps.ocp.v7hjl.sandbox2288.opentlc.com` |
| App Repo | `https://github.com/rrbanda/type-a-cmp-mcp` |
| GitOps Repo | `https://github.com/rrbanda/type-a-cmp-mcp-gitops` |

---

## Architecture

```
Developer
    │
    ▼
┌──────────────────────────────────────────────────────────────┐
│  Red Hat Developer Hub (Backstage)                           │
│  ┌────────────────────┐                                      │
│  │  FastMCP Template   │──→ 2 GitHub repos (app + gitops)    │
│  │  (one-click)        │──→ Tekton CI webhook                │
│  └────────────────────┘──→ ArgoCD Application                │
│                           ──→ Catalog registration            │
└──────────────────────────────────────────────────────────────┘
    │                                          │
    ▼                                          ▼
┌──────────────┐    git push     ┌─────────────────────────────┐
│  Dev Spaces   │ ──────────────→│  Tekton CI Pipeline          │
│  (cloud IDE)  │                │  clone → build → push image  │
│               │                │  → update GitOps repo         │
│  ┌──────────┐ │                └──────────────┬──────────────┘
│  │  Goose    │ │                               │
│  │  Agent    │ │                               ▼
│  └─────┬────┘ │                ┌─────────────────────────────┐
│        │      │                │  ArgoCD (GitOps CD)          │
└────────┼──────┘                │  watches gitops repo          │
         │                       │  → syncs to OpenShift         │
         ▼                       └─────────────────────────────┘
┌─────────────────────┐
│  Llama Stack         │
│  ┌─────────────────┐ │
│  │ vLLM on RHOAI   │ │
│  │ gpt-oss-120b    │ │
│  │ (on-prem LLM)   │ │
│  └─────────────────┘ │
└─────────────────────┘
```
