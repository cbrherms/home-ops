<div align="center">

# CBRHerms' Home Operations

[![Talos](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.sheartech.uk%2Fquery%3Fformat%3Dendpoint%26metric%3Dtalos_version&style=for-the-badge&logo=talos&logoColor=white&color=blue&label=%20)](https://www.talos.dev/)&nbsp;&nbsp;
[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.sheartech.uk%2Fquery%3Fformat%3Dendpoint%26metric%3Dkubernetes_version&style=for-the-badge&logo=kubernetes&logoColor=white&color=blue&label=%20)](https://www.talos.dev/)&nbsp;&nbsp;
[![GitHub last commit](https://img.shields.io/github/last-commit/cbrherms/home-ops?color=blue&style=for-the-badge&logoColor=white&logo=github&label=%20)](https://github.com/cbrherms/home-ops/commits/main)

[![Age-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.sheartech.uk%2Fquery%3Fmetric%3Dcluster_age_days&style=flat-squaree&label=Age)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;&nbsp;
[![Uptime-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.sheartech.uk%2Fquery%3Fmetric%3Dcluster_uptime_days&style=flat-square&label=Uptime)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;&nbsp;
[![Active-Alerts](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.sheartech.uk%2Fquery%3Fmetric%3Dprometheus_active_alerts&style=flat-square&label=Firing%20Alerts)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;&nbsp;
[![Node-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.sheartech.uk%2Fquery%3Fmetric%3Dcluster_node_count&style=flat-square&label=Nodes)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;&nbsp;
[![Pod-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.sheartech.uk%2Fquery%3Fmetric%3Dcluster_pod_count&style=flat-square&label=Pods&color=green)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;&nbsp;
[![CPU-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.sheartech.uk%2Fquery%3Fmetric%3Dcluster_cpu_usage&style=flat-square&label=CPU)](https://github.com/kashalls/kromgo/)

</div>

## Introduction

Welcome to my repository, where I manage my homelab infrastructure using [Infrastructure as Code (IaC)](https://en.wikipedia.org/wiki/Infrastructure_as_code) and [GitOps](https://www.gitops.tech/) principles where possible. This repository serves as the single source of truth for my Kubernetes cluster, which is gradually becoming the backbone of my home operations as I use it to further my learning. The cluster is built and managed using a variety of tools, including [Terraform](https://www.terraform.io/), [Ansible](https://www.ansible.com/), [Kubernetes](https://kubernetes.io/), [Flux](https://fluxcd.io/), [GitHub Actions](https://github.com/features/actions), and updated using [Renovate](https://renovatebot.com/).

### Why? - A History

I have gone through various iterations of my homelab, starting off with a simple single media server running Ubuntu 16.04. As my needs grew, I moved on to a dockerised environment, which allowed me to run multiple applications in isolated containers. After adding more hardware, this setup evolved into a virtualised Proxmox environment with multiple Docker hosts, providing better resource management and isolation. The longest-lasting version of my homelab was a Docker Swarm setup, which offered high availability and scalability for my containerised applications. Over the last year, I have been transitioning to Kubernetes after an initial play around with an older test cluster. Kubernetes provides a more robust and scalable platform for managing my home infrastructure, and this repository reflects that evolution.

### Thanks

This repository is based on the [Flux Cluster Template](https://github.com/onedr0p/flux-cluster-template) by [onedr0p](https://github.com/onedr0p), who was a large part of the inspiration to delve further into Kubernetes managed by Flux and the GitOps way. It also incorporates information learnt from and cherry-picked from examples on [kubesearch.dev](https://kubesearch.dev) and the [Home Operations Discord](https://discord.gg/home-operations) community. Special thanks to everyone who has contributed to these resources and communities.

## Cluster Overview

The cluster nodes are virtualised and running in my Proxmox environment, split across multiple VM hosts to allow redundancy. They are running [Talos](https://www.talos.dev/), a modern, secure, and immutable operating system for Kubernetes. Talos is designed to provide a minimal and secure environment for running Kubernetes, with no SSH access and all configuration managed via API.

The cluster includes:

- **Networking**: Managed by [Cilium](https://cilium.io/) for secure and efficient network policies.
- **Storage**: Handled by [Longhorn](https://longhorn.io/) and [OpenEBS](https://openebs.io/) for persistent storage solutions.
- **Monitoring and Observability**: Implemented using [Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/), and [Loki](https://grafana.com/oss/loki/) for comprehensive monitoring and logging.
- **Secrets Management**: Secured with [1Password](https://1password.com/) and [External Secrets](https://external-secrets.io/).
- **Ingress Management**: Managed by [Ingress-NGINX](https://kubernetes.github.io/ingress-nginx/) for routing external traffic to internal services.

### GitOps

[Flux](https://fluxcd.io) watches my cluster in the Kubernetes folder and makes the changes to my cluster based on the state within my Git repository.

The way Flux works for my cluster is by recursively searching the `kubernetes/apps` folder until it finds the top most `kustomization.yaml` per directory and then apply all resources listed within. The `kustomization.yaml` file will contain a namespace and one or more `ks.yaml` Flux kustomizations. Within those Flux kustomzations will be `HelmReleases` which dictate the resources that are applied for the specific application.

[Renovate](https://github.com/renovatebot/renovate) watches everything within the repository looking for updates. Once an update is found it creates a Pull Request in Github, allowing me to review changes before merging them. Once these changes are merged, Flux picks them up and applies the changes.

### Directories

This Git repostories contains the following directories under [Kubernetes](https://github.com/ewatkins/talos-cluster/tree/main/kubernetes)

```sh
📁 kubernetes
├── 📁 apps           # applications
├── 📁 bootstrap      # bootstrap procedures
├── 📁 flux           # core flux configuration
└── 📁 templates      # re-useable components
```

---

## ☁️ Cloud Dependencies

While most of my infrastructure and workloads are self-hosted I do rely upon the cloud for certain key parts of my setup. This saves me from having to worry about two things. (1) Dealing with chicken/egg scenarios and (2) services I critically need whether my cluster is online or not.

| Service                                     | Use                                                            | Cost           |
|---------------------------------------------|----------------------------------------------------------------|----------------|
| [1Password](https://1password.com/)         | Secrets with [External Secrets](https://external-secrets.io/)  | ~£45/yr        |
| [Cloudflare](https://www.cloudflare.com/)   | Domains, Tunnels, and R2                                       | ~£20/yr        |
| [GitHub](https://github.com/)               | Hosting this repository and continuous integration/deployments | Free           |
| [Let's Encrypt](https://letsencrypt.org/)   | Issuing SSL Certificates with Cert Manager                     | Free           |
| [Microsoft 365](https://microsoft.com/)     | Email Hosting (Don't judge me...)                              | ~£70/yr        |
| [Pushover](https://pushover.net/)           | Kubernetes Alerts and application notifications                | $5             |
| [Healthchecks.io](https://healthchecks.io/) | Heartbeat Monitoring for AlertManager and Internet             | Free           |
|                                             |                                                                | Total: ~£11/mo |
---

## 🌐 DNS

### Public DNS

I am currently using [ExternalDNS](https://github.com/kubernetes-sigs/external-dns) to create public DNS records in Cloudflare for externally facing applications and endpoints. I use the external ingress name and external ingress annotations to determine if an application is internal or external.

### Home DNS

For my Home DNS I am using unbound built in to my pfSense router. Along with unbound I am utilizing the CoreDNS plugin, [k8s_gateway](https://github.com/ori-edge/k8s_gateway) to be able to automatically resolve internal dns using split DNS and dnsmasq. All DNS lookups involving my cluster's domain name are forwarded directly to the k8s gateway IP using an override within unbound.

---

## 🔧 Hardware

### Virtualisation Hosts

| Name        | Device       | CPU          | Cores    | RAM   | OS     | Purpose            |
|-------------|--------------|--------------|----------|-------|--------|--------------------|
| PVE-05      | Dell R730XD  | 2x E5-2680v4 | 56 Cores | 256GB | PVE8.x | Main VM node 1     |
| PVE-06      | Dell R630    | 2x E5-2690v4 | 56 Cores | 128GB | PVE8.x | Main VM node 2     |
| PVE-R330-01 | Dell R330    | E3-1270 v5   | 8 Cores  | 48GB  | PVE8.x | Aux VM node        |
| PVE-HA      | Gigabyte NUC | i5-4200U     | 4 Cores  | 16GB  | PVE8.x | Homeassistant host |

Total CPU: 124 Cores
Total RAM: 96GB

Note: 4 nodes not best practice, currently supported by quorum devices until HA is migrated to another node and PVE-HA decommissioned

### Kubernetes Cluster

| Name            | Device       | CPU      | Cores  | RAM  | OS Disk  | Data Disk   | OS    | Purpose           |
|-----------------|--------------|----------|--------|------|----------|-------------|-------|-------------------|
| talos-master-01 | Proxmox VM   | Virtual  | 6 vCPU | 16GB | 64GB SSD | 500GB NVME  | Talos | k8s control-plane |
| talos-master-02 | Proxmox VM   | Virtual  | 6 vCPU | 16GB | 64GB SSD | 500GB NVME  | Talos | k8s control-plane |
| talos-master-03 | Proxmox VM   | Virtual  | 6 vCPU | 16GB | 64GB SSD | 500GB NVME  | Talos | k8s control-plane |
| talos-worker-01 | Proxmox VM   | Virtual  | 6 vCPU | 16GB | 64GB SSD | 500GB NVME  | Talos | k8s worker        |
| talos-worker-02 | Proxmox VM   | Virtual  | 6 vCPU | 16GB | 64GB SSD | 500GB NVME  | Talos | k8s worker        |
| talos-worker-03 | Proxmox VM   | Virtual  | 6 vCPU | 16GB | 64GB SSD | 500GB NVME  | Talos | k8s worker        |

Total CPU: 36 threads
Total RAM: 96GB

### Supporting Hardware

| Name   | Device           | CPU           | OS Disk    | Data Disk  | RAM   | OS           | Purpose        |
|--------|------------------|---------------|------------|------------|-------|--------------|----------------|
| Unrad  | Custom rackmount | Ryzen 5 5600X | 32GB USB   | 1TB NVMe   | 64GB  | Unraid       | NAS/NFS/Backup |
| DAS    | NetApp DS4246    | -             | -          | 132TB      | -     | -            | DAS w/ Parity  |

---
