# Service Discovery with ExternalDNS

## Introduction

ExternalDNS synchronizes exposed Kubernetes Services and Ingresses with DNS providers.

## Deploying ExternalDNS

## Prerequisites

* YTT installed (<https://github.com/k14s/ytt/releases>).
* Workload cluster deployed.

### Workload cluster

1. Create config.yaml file (Supported configurations key/value pairs are below)

   ```yaml
   #@data/values
   ---
   <key1>:<value1>
   <key2>:<value2>
   ```

2. Deploy ExternalDNS

    ```sh
    ytt --ignore-unknown-comments -f common/ -f service-discovery/external-dns/ -f <config.yaml> | kubectl apply -f-
    ```

## Configurations

The default configuration values are in service-discovery/external-dns/values.yaml

| Parameter                                          | Description                                      | Type                 | Default                        |
|----------------------------------------------------|--------------------------------------------------|----------------------|--------------------------------|
| `externalDns.namespace`                            | Namespace where external-dns will be deployed    | `string`             | `tanzu-system-service-discovery` |
| `externalDns.image.repository`                     | Repository containing external-dns image         | `string`             | `projects.registry.vmware.com/tkg`        |
| `externalDns.image.name`                           | Name of external-dns                             | `string`             | `external-dns`                   |
| `externalDns.image.tag`                            | ExternalDNS image tag                            | `string`             | `v0.7.4_vmware.1`                |
| `externalDns.image.pullPolicy`                     | ExternalDNS image pull policy                    | `string`             | `IfNotPresent`                   |
| `externalDns.deployment.annotations`               | Annotations on the external-dns deployment       | `map<string,string>` | `{}`                             |
| `externalDns.deployment.args`                      | Args passed via command-line to external-dns     | `list<string>`       | `[]` ( Mandatory parameter )     |
| `externalDns.deployment.env`                       | Environment variables to pass to external-dns    | `list<string>`       | `[]`                             |
| `externalDns.deployment.securityContext`           | Security context of the external-dns container   | `SecurityContext`    | `{}`                             |
| `externalDns.deployment.volumeMounts`              | Volume mounts of the external-dns container      | `list<VolumeMount>`  | `[]`                             |
| `externalDns.deployment.volumes`                   | Volumes of the external-dns pod                  | `list<Volume>`       | `[]`                             |

Follow [the external-dns docs](https://github.com/kubernetes-sigs/external-dns#running-externaldns) for guidance on how to configure ExternalDNS for your provider.

Fill out the deployment parameters as needed for your ExternalDNS provider.
