# ExternalDNS Extension

## Prerequisites

* Workload cluster deployed.
* ytt installed (<https://github.com/k14s/ytt/releases>)
* kapp installed (<https://github.com/k14s/kapp/releases>)

### Deploy ExternalDNS extension

1. Install TMC's extension manager

    ```sh
    kubectl apply -f ../../tmc-extension-manager.yaml
    ```

2. Install kapp-controller

   This step is to be performed only for TKGS. For TKGm, kapp-controller is installed on the workload cluster by default.

    ```sh
    kubectl apply -f ../../kapp-controller.yaml
    ```

3. Create external-dns namespace

    ```sh
    kubectl apply -f namespace-role.yaml
    ```

4. Copy `external-dns-data-values.yaml.example` to `external-dns-data-values.yaml`

   Configure ExternalDNS data values in `external-dns-data-values.yaml`

   Supported configurations are documented in [external-dns-configurations](../../../service-discovery/external-dns/README.md)

    ```sh
    cp external-dns-data-values.yaml.example external-dns-data-values.yaml
    ```

5. Create a secret with data values

    ```sh
    kubectl create secret generic external-dns-data-values --from-file=values.yaml=external-dns-data-values.yaml -n tanzu-system-service-discovery
    ```

6. Deploy ExternalDNS extension

    ```sh
    kubectl apply -f external-dns-extension.yaml
   ```

7. Retrieve status of an extension

    ```sh
    kubectl get extension external-dns -n tanzu-system-service-discovery
    kubectl get app external-dns -n tanzu-system-service-discovery
    ```

   ExternalDNS app status should change to `Reconcile Succeeded` once ExternalDNS is deployed successfully

   View detailed status

   ```sh
   kubectl get app external-dns -n tanzu-system-service-discovery -o yaml
   ```

### Update ExternalDNS extension

1. Get ExternalDNS data values from secret

    ```sh
    kubectl get secret external-dns-data-values -n tanzu-system-service-discovery -o 'go-template={{ index .data "values.yaml" }}' | base64 -d > external-dns-data-values.yaml
    ```

2. Update ExternalDNS data values in external-dns-data-values.yaml

3. Update ExternalDNS data values secret

    ```sh
    kubectl create secret generic external-dns-data-values --from-file=values.yaml=external-dns-data-values.yaml -n tanzu-system-service-discovery -o yaml --dry-run | kubectl replace -f-
    ```

   ExternalDNS extension will be reconciled again with the above data values

   **NOTE:**
   By default, kapp-controller will sync apps every 5 minutes. So, the update should take effect in <= 5 minutes.
   If you want the update to take effect immediately, change syncPeriod in `external-dns-extension.yaml` to a lesser value
   and apply ExternalDNS extension `kubectl apply -f external-dns-extension.yaml`.

4. Refer to `Retrieve status of an extension` in [Deploy ExternalDNS Extension](#deploy-external-dns-extension) to retrieve the status of an extension

### Delete ExternalDNS extension

1. Delete ExternalDNS extension

    ```sh
    kubectl delete -f external-dns-extension.yaml
    kubectl delete app external-dns -n tanzu-system-service-discovery
    ```

2. Refer to `Retrieve status of an extension` in [Deploy ExternalDNS Extension](#deploy-external-dns-extension) to retrieve the status of an extension

   If extension is deleted successfully, then get of both ExternalDNS extension and app should return `Not Found`

3. Delete external-dns namespace

   **NOTE: Do not delete namespace-role.yaml before app is deleted fully, as it will lead to errors due to service account used by kapp-controller being deleted**

    ```sh
    kubectl delete -f namespace-role.yaml
    ```

### Test template rendering

1. Test if ExternalDNS templates are rendered correctly

    ```sh
    ytt --ignore-unknown-comments -f ../../../common -f ../../../service-discovery/external-dns -f external-dns-data-values.yaml
    ```
