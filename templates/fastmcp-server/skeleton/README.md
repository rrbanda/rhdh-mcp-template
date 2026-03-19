# ${{ values.name }}

${{ values.description }}

## Overview

This is a [FastMCP](https://github.com/jlowin/fastmcp) server that exposes a
REST API as a set of MCP (Model Context Protocol) tools. AI agents and LLMs can
invoke these tools to interact with the upstream API.

## Local Development

### Prerequisites

- Python 3.11+
- The upstream API running at `${{ values.apiBaseUrl }}`

### Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Run

```bash
python3 mcp_server.py
```

The server starts on `http://0.0.0.0:${{ values.port }}/mcp` using the
streamable HTTP transport.

## Container Build

```bash
docker build -t ${{ values.name }} .
docker run -p ${{ values.port }}:${{ values.port }} ${{ values.name }}
```

## CI/CD with Tekton on OpenShift

This project includes a Tekton Pipeline that automates building the container
image and deploying it to OpenShift.

### First-Time Setup

Run the setup script to create the namespace and apply Tekton resources:

```bash
cd tekton
./setup.sh ${{ values.namespace }}
```

This provisions:

- **Pipeline** (`${{ values.name }}-ci-cd`) -- clones the repo, builds with
  buildah, pushes to the internal registry, and deploys to OpenShift.
- **EventListener** -- receives GitHub webhook events and triggers pipeline runs
  automatically on push to `main`.
- **TriggerBinding / TriggerTemplate** -- maps GitHub push payloads to pipeline
  parameters.

### Manual Pipeline Run

```bash
oc create -f tekton/pipelinerun.yaml
```

### Automatic Triggers (GitHub Webhook)

After running `setup.sh`, configure a GitHub webhook:

1. Go to **Settings > Webhooks** in your GitHub repository.
2. Set **Payload URL** to the EventListener route printed by `setup.sh`.
3. Set **Content type** to `application/json`.
4. Select **Just the push event**.

Every push to `main` will automatically build and deploy.

### Manual Deployment (without pipeline)

Apply the included manifests directly:

```bash
oc apply -f deploy/deployment.yaml
```

This creates a Deployment, Service, and Route in the `${{ values.namespace }}`
namespace. The Route provides a TLS-terminated public endpoint.

## Customization

Edit `mcp_server.py` to replace the placeholder tools (`list_items`,
`get_item`, `create_item`) with tools that match your actual API endpoints.
Each `@mcp.tool` function maps to one REST endpoint:

| HTTP Method | MCP Tool Pattern |
|-------------|-----------------|
| GET (list)  | Tool that returns a list of resources |
| GET (by id) | Tool that returns a single resource |
| POST        | Tool that creates a resource |
| PATCH / PUT | Tool that updates a resource |
| DELETE      | Tool that removes a resource |
