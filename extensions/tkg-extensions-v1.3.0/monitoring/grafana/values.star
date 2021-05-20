load("@ytt:data", "data")
load("@ytt:assert", "assert")
load("/globals.star", "globals")

def validate_monitoring_namespace():
  # Namespace checking
  data.values.monitoring.namespace or assert.fail("missing monitoring.namespace")
end

def validate_grafana():
  validate_funcs = [validate_monitoring_namespace,
                    validate_grafana_password,
                    validate_grafana_deployment,
                    validate_grafana_image,
                    validate_grafana_rbac_component_names]
  for validate_func in validate_funcs:
    validate_func()
  end
end

def validate_grafana_deployment():
  data.values.monitoring.grafana.deployment.replicas or assert.fail("Grafana deployment replicas should be provided")
end

def validate_grafana_image():
  # Image Name and version checking
  data.values.monitoring.grafana.image.name or assert.fail("missing grafana.image.name")
  data.values.monitoring.grafana.image.tag or assert.fail("missing grafana.image.tag")
  data.values.monitoring.grafana.image.repository or assert.fail("missing grafana.image.repository ")
  data.values.monitoring.grafana.image.pullPolicy or assert.fail("missing grafana.image.pullPolicy")
end

def validate_grafana_rbac_component_names():
  data.values.monitoring.grafana.service_account_name or assert.fail("missing grafana.service_account_name")
  data.values.monitoring.grafana.cluster_role_name or assert.fail("missing grafana.cluster_role_name")
end

def validate_grafana_password():
  # Grafana password checking
  data.values.monitoring.grafana.secret.admin_password or assert.fail("missing grafana password")
end

#export
values = data.values

# validate monitoring components data values
validate_grafana()
