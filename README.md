# Infra

> 우리집을 클라우드로!! 

```mermaid
flowchart LR
  EXT["External Users (Internet)"]
  CF["Cloudflare Edge"]

  subgraph LAN["Home LAN 172.16.0.0/16"]
    C["Clients"]
    R["A2004MU Router"]
  end

  subgraph K8S["Kubernetes Cluster"]
    CP["Control Plane Node<br/>soyo (172.16.1.21)"]
    W1["Worker VM 1<br/>k8s-worker-1"]
    WN["Worker VM N"]

    MB["MetalLB (L2)"]
    DNSVIP["DNS VIP<br/>172.16.200.53"]
    TRAEFIKVIP["Traefik VIP<br/>172.16.200.20"]

    COREDNS["CoreDNS<br/>internal-dns namespace"]
    TRAEFIK["Traefik<br/>edge namespace"]
    CLOUDFLARED["cloudflared tunnel<br/>edge namespace"]
    APPS["Apps/Services<br/>n8n, Grafana, Hubble, etc."]
  end

  EXT --> CF
  CF -->|"Cloudflare Tunnel"| CLOUDFLARED
  CLOUDFLARED --> TRAEFIK

  C --- R
  R --- CP
  R --- W1
  R --- WN

  MB --> DNSVIP
  MB --> TRAEFIKVIP

  C -->|"DNS query (*.home.internal)"| DNSVIP
  DNSVIP --> COREDNS

  C -->|"HTTP(S) request"| TRAEFIKVIP
  TRAEFIKVIP --> TRAEFIK
  TRAEFIK --> APPS
```

## Traffic Flow

Internal LAN path:
1. Client queries `*.home.internal` to `172.16.200.53`.
2. Internal DNS returns `172.16.200.20` (Traefik VIP).
3. Client sends HTTP(S) request to Traefik.
4. Traefik routes to target service in cluster.

External Internet path:
1. External user reaches Cloudflare.
2. Cloudflare Tunnel forwards traffic to `cloudflared` in `edge` namespace.
3. `cloudflared` forwards to Traefik.
4. Traefik routes to target service in cluster.

## Service Networks 

- LAN network: `172.16.0.0/16`
- VIPs used on LAN:
  - `172.16.200.53` (internal DNS)
  - `172.16.200.20` (Traefik ingress)
- Kubernetes internal networks:
  - Pod IPs are allocated on cluster-internal ranges (for example `10.0.x.x`)
  - Service `ClusterIP` addresses are also cluster-internal (for example `10.96.x.x`, `10.105.x.x`)

This repository keeps the service network model above as-is.


## Kubernetes Cluster Architecture

```mermaid
flowchart TB
  subgraph Cluster["Kubernetes Cluster"]
    direction TB

    subgraph NS_Edge["Namespace: edge"]
      direction TB
      ROUTES["IngressRoute"]
      CFD["cloudflared"]
      TRAEFIK2["Traefik"]
      ROUTES --> TRAEFIK2
      CFD --> TRAEFIK2
    end

    subgraph NodeRow["Cluster Nodes"]
      direction LR
      subgraph ControlPlane["Control Plane Node"]
        direction TB
        API["kube-apiserver"]
        SCHED["kube-scheduler"]
        CTRL["kube-controller-manager"]
        ETCD["etcd"]
        API --> SCHED
        API --> CTRL
      end

      subgraph Worker1["Worker VM: k8s-worker-1"]
        direction TB
        KP1["kubelet"]
        PODS1["App Pods"]
        PROXY1["Cilium datapath"]
      end

      subgraph WorkerN["Worker VM: k8s-worker-N"]
        direction TB
        KPN["kubelet"]
        PODSN["App Pods"]
        PROXYN["Cilium datapath"]
      end
    end
  end

  API --> KP1
  API --> KPN
  TRAEFIK2 --> PODS1
  PODS1 --> PROXY1
  PROXY1 -->|"pod-to-pod (Cilium)"| PROXYN
  PROXYN --> PODSN
```


## Infrastructure Description

- control plane:
  - runs Kubernetes control plane components
  - participates in service exposure through MetalLB L2 advertisement
- worker VMs:
  - run application workloads (n8n, Grafana, monitoring agents, etc.)
  - receive routed traffic from Traefik based on host rules
- MetalLB:
  - allocates and advertises LAN VIPs for `LoadBalancer` services
  - allows direct access from home LAN clients without external cloud LB
- Internal CoreDNS (`internal-dns` namespace):
  - serves `home.internal` zone
  - returns Traefik VIP for service hostnames
- Traefik (`edge` namespace):
  - receives HTTP(S) traffic on `172.16.200.20`
  - forwards requests to backend services using host/path rules

