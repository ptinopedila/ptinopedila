> **Created:** `2026-08-26T05:01+03:00` · **Last updated:**
> `2026-08-26T05:01+03:00`

# CUDA containers on Ptinopedila NVIDIA

The `ptinopedila-home-nvidia` image inherits
[`projectbluefin/bluefin-nvidia`](../recipes/ptinopedila-home-nvidia.yml). Project
Bluefin's NVIDIA image includes the NVIDIA driver integration,
`nvidia-container-toolkit-base`, and a Container Device Interface (CDI)
configuration for rootless Podman. This allows containers to access the
system's NVIDIA GPU for CUDA and other GPU-accelerated workloads.

The host does not normally need a separate CUDA Toolkit installation. The
application container supplies its CUDA user-space libraries, while the host
supplies a sufficiently recent NVIDIA driver and passes the GPU into the
container. Choose a container image whose CUDA requirements are compatible
with the installed driver.

Check the host and the CDI devices:

```sh
nvidia-smi
nvidia-ctk cdi list
```

Run a CUDA container by requesting all NVIDIA GPUs through CDI:

```sh
podman run --rm \
  --device nvidia.com/gpu=all \
  docker.io/nvidia/cuda:12.9.0-base-ubuntu22.04 \
  nvidia-smi
```

Successful `nvidia-smi` output from inside the container confirms that Podman
can see the GPU and load the host's NVIDIA driver. Applications such as
PyTorch, TensorFlow, and CUDA development environments can use the same CDI
device request with a suitable container image.

References:

- [Bluefin monthly reports](https://docs.projectbluefin.io/reports/) — records
  the installation of `nvidia-container-toolkit-base` and CDI configuration in
  NVIDIA images.
- [NVIDIA Container Toolkit](https://github.com/NVIDIA/nvidia-container-toolkit)
  — explains the host-driver requirements and that a host CUDA Toolkit is not
  required.
- [NVIDIA CDI support](https://github.com/NVIDIA/nvidia-container-toolkit/blob/main/cmd/nvidia-ctk/README.md)
  — documents CDI device generation and Podman's
  `--device nvidia.com/gpu=...` syntax.
