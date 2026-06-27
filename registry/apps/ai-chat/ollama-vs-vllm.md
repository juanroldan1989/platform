# Ollama vs vLLM

This application currently uses Ollama as the model runtime behind Open WebUI.

```text
Open WebUI -> Ollama -> pulled Ollama models -> GPU
```

The `ollama-model-puller` Job downloads models with `ollama pull`, stores them in the Ollama PVC, and makes them available through the Ollama API for Open WebUI.

## Ollama

Ollama is a simple and developer-friendly way to run local or self-hosted models.

It is a good fit when:

- The main use case is an interactive chat UI.
- You want easy model management with `ollama pull`.
- You are serving a small team or low-concurrency workload.
- Operational simplicity matters more than maximum throughput.
- You want a quick and reliable way to run models behind Open WebUI.

Ollama is the right choice for the current AI chat setup because it is simple, works well with Open WebUI, and keeps the deployment easy to operate.

## vLLM

vLLM is a high-throughput inference server designed for production LLM serving.

It is a better fit when:

- You have many concurrent users or API clients.
- You need higher token throughput from the same GPU.
- You want an OpenAI-compatible API endpoint.
- You need advanced serving features such as continuous batching, prefix caching, quantization, or distributed inference.
- You are exposing models as an internal platform service, not only through a chat UI.

vLLM is more serving-oriented than Ollama. It is often the better option when performance, concurrency, and GPU utilization become more important than ease of use.

## Cost Considerations

vLLM can help reduce cost when the GPU is under sustained load.

The savings come from better GPU utilization: if vLLM can serve more requests per GPU, you may need fewer GPU nodes for the same traffic. This matters most when there are many users, many requests, or high token throughput requirements.

vLLM does not automatically make an idle GPU cheaper. If the node is mostly unused, the cost is still dominated by the running GPU instance.

## Practical Recommendation

Use Ollama for the current Open WebUI-based chat application.

Consider vLLM later when one of these becomes true:

- Ollama becomes a throughput or latency bottleneck.
- Multiple applications need direct model API access.
- You want to expose an OpenAI-compatible endpoint.
- You need to serve higher concurrency from the same GPU.
- You start scaling to larger or multiple GPU nodes.

A future architecture could support both:

```text
Open WebUI -> Ollama for simple chat models
Open WebUI -> vLLM for production-grade model serving
Apps/API clients -> vLLM directly
```

In short: Ollama is the best first step for simplicity. vLLM is the next step when production inference performance and scale matter.
