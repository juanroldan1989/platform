# AI Chat Application

This Helm chart deploys a simple GPU-backed AI chat stack made of two main components: Ollama and Open WebUI.

```text
User browser
     |
     v
Open WebUI
     |
     v
Ollama API
     |
     v
GPU-backed model inference
```

The application depends on the NVIDIA GPU Operator being installed in the target cluster. The operator prepares GPU nodes so Kubernetes can schedule GPU workloads and expose GPU capacity to pods.

## Components

### NVIDIA GPU Operator

The NVIDIA GPU Operator is installed as a platform add-on before this application runs. It configures the GPU node with the NVIDIA driver, device plugin, and GPU feature discovery components needed by Kubernetes.

For this application, the important outcomes are:

- GPU nodes are labelled with GPU-related metadata, including `nvidia.com/gpu.present`.
- Kubernetes exposes GPU capacity as the schedulable resource `nvidia.com/gpu`.
- Pods can request GPU access through standard Kubernetes resource limits.
- Ollama can be scheduled onto a GPU node and use the GPU for model inference.

Without the GPU Operator, the Ollama pod would not be able to request `nvidia.com/gpu: 1`, and Kubernetes would not know how to assign GPU capacity to the workload.

### Ollama

Ollama is the model runtime. It loads and serves LLM models, exposes an internal API on port `11434`, and uses the GPU for inference.

In this chart, Ollama:

- Requests one GPU with `nvidia.com/gpu: 1`.
- Schedules only on GPU-capable nodes using `nvidia.com/gpu.present: "true"`.
- Stores downloaded models in the `ollama-data` PVC mounted at `/root/.ollama`.
- Is exposed inside the cluster through the `ollama` Service.

### Open WebUI

Open WebUI is the browser-based chat interface. It does not run models directly; it connects to Ollama and lets users interact with the models through a web UI.

In this chart, Open WebUI:

- Runs without a GPU request.
- Connects to Ollama through `OLLAMA_BASE_URL` and `OLLAMA_BASE_URLS`.
- Stores application and user data in the `open-webui-data` PVC mounted at `/app/backend/data`.
- Is exposed externally through an Ingress.

## Namespace

The chart uses a per-cluster namespace:

```text
ai-chat-<cluster-name>
```

For the London cluster, resources are deployed into:

```text
ai-chat-london
```

## Model Pull Automation

Models are pulled automatically through an Argo CD `PostSync` Job named `ollama-model-puller`.

The Job waits until the Ollama API is reachable, then runs `ollama pull` for each model configured in `values.yaml`.

Default models:

```text
qwen2.5:7b
mistral:7b
llama3.1:8b
```

Because models are stored in the `ollama-data` PVC, repeated syncs do not need to download models again unless the model is missing or changed.

## Access

For the London cluster, Open WebUI is exposed at:

```text
https://ai-chat.london.automatalife.com
```

## Configuration

The main settings live in `values.yaml`:

- `aiChat.namespacePrefix`: namespace prefix used with the cluster name.
- `aiChat.ollama.image`: Ollama container image.
- `aiChat.ollama.storage`: storage size for downloaded models.
- `aiChat.ollama.models`: models pulled by the PostSync Job.
- `aiChat.openWebui.image`: Open WebUI container image.
- `aiChat.openWebui.storage`: storage size for Open WebUI data.
