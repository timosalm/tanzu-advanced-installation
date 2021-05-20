load("@ytt:data", "data")
load("globals.star", "globals")
load("@ytt:assert", "assert")
load("/globals.star", "validate_infrastructure_provider")

SERVICE_TYPE_NODEPORT = "NodePort"
SERVICE_TYPE_LOADBALANCER = "LoadBalancer"

def validate_dex():
  validate_funcs = [validate_infrastructure_provider,
                    validate_dex_namespace,
                    validate_dex_config,
                    validate_dex_image,
                    validate_dex_certificate,
                    validate_dex_deployment,
                    validate_dex_service,
                    validate_static_client]
  for validate_func in validate_funcs:
    validate_func()
  end
end

def validate_dex_namespace():
  data.values.dex.namespace or assert.fail("Dex namespace should be provided")
end

def validate_dex_config():
  globals.infrastructure_provider in ("aws", "vsphere", "azure") or assert.fail("Dex supports provider aws, vsphere or azure")
  if globals.infrastructure_provider == "vsphere":
    data.values.dns.vsphere.ipAddresses or assert.fail("Dex MGMT_CLUSTER_IP should be provided for vsphere provider")
    data.values.dex.config.issuerPort or assert.fail("Dex config issuerPort should be provided for vsphere provider")
  end
  if globals.infrastructure_provider == "aws":
    data.values.dns.aws.DEX_SVC_LB_HOSTNAME or assert.fail("Dex oidc issuer DEX_SVC_LB_HOSTNAME should be provided for aws provider")
  end
  if globals.infrastructure_provider == "azure":
    data.values.dns.azure.DEX_SVC_LB_HOSTNAME or assert.fail("Dex DEX_SVC_LB_HOSTNAME should be provided for azure provider")
  end
  data.values.dex.config.connector in ("oidc", "ldap") or assert.fail("Dex connector should be oidc or ldap")
  if data.values.dex.config.connector == "oidc":
    validate_oidc_config()
  end
  if data.values.dex.config.connector == "ldap":
    validate_ldap_config()
  end
  data.values.dex.config.oauth2 or assert.fail("Dex oauth2 should be provided")
  data.values.dex.config.storage or assert.fail("Dex storage should be provided")
end

def validate_oidc_config():
  data.values.dex.config.oidc.CLIENT_ID or assert.fail("Dex oidc CLIENT_ID should be provided")
  data.values.dex.config.oidc.CLIENT_SECRET or assert.fail("Dex oidc CLIENT_SECRET should be provided")
  data.values.dex.config.oidc.issuer or assert.fail("Dex oidc issuer should be provided")
  data.values.dex.config.oidc.clientID == "$OIDC_CLIENT_ID" or assert.fail("Dex oidc clientID should be $OIDC_CLIENT_ID. Do not change it")
  data.values.dex.config.oidc.clientSecret == "$OIDC_CLIENT_SECRET" or assert.fail("Dex oidc clientSecret should be $OIDC_CLIENT_SECRET. Do not change it")
end

def validate_ldap_config():
  data.values.dex.config.ldap.host or assert.fail("Dex ldap <LDAP_HOST> should be provided")
  data.values.dex.config.ldap.insecureSkipVerify in (True, False)
  if data.values.dex.config.ldap.userSearch :
    data.values.dex.config.ldap.userSearch.baseDN or assert.fail("Dex ldap userSearch enabled. baseDN should be provided")
  end
  if data.values.dex.config.ldap.groupSearch :
    data.values.dex.config.ldap.groupSearch.baseDN or assert.fail("Dex ldap groupSearch enabled. baseDN should be provided")
  end
end

def validate_dex_image():
  data.values.dex.image.name or assert.fail("Dex image name should be provided")
  data.values.dex.image.tag or assert.fail("Dex image tag should be provided")
  data.values.dex.image.repository or assert.fail("Dex image repository should be provided")
  data.values.dex.image.pullPolicy or assert.fail("Dex image pullPolicy should be provided")
end

def validate_dex_certificate():
  data.values.dex.certificate.duration or assert.fail("Dex certificate duration should be provided")
  data.values.dex.certificate.renewBefore or assert.fail("Dex certificate renewBefore should be provided")
end

def validate_dex_deployment():
  data.values.dex.deployment.replicas or assert.fail("Dex deployment replicas should be provided")
end

def validate_dex_service():
  if data.values.dex.service.type:
    data.values.dex.service.type in ("LoadBalancer", "NodePort") or assert.fail("Dex service type should be LoadBalancer or NodePort")
  end
  if globals.infrastructure_provider == "aws":
    data.values.dns.aws.DEX_SVC_LB_HOSTNAME or assert.fail("Dex aws dnsname DEX_SVC_LB_HOSTNAME should be provided")
  end
  if globals.infrastructure_provider == "vsphere":
    data.values.dns.vsphere.ipAddresses[0] or assert.fail("Dex vsphere dns at least one ipaddress should be provided")
  end
  if globals.infrastructure_provider == "azure":
    data.values.dns.azure.DEX_SVC_LB_HOSTNAME or assert.fail("Dex azure dnsname DEX_SVC_LB_HOSTNAME should be provided")
  end
end

def get_service_type():
  if globals.infrastructure_provider == "vsphere":
    return SERVICE_TYPE_NODEPORT
  else:
    return SERVICE_TYPE_LOADBALANCER
  end
end

def get_dex_service_type():
  if hasattr(data.values.dex, "service") and hasattr(data.values.dex.service, "type") and data.values.dex.service.type != None:
    return data.values.dex.service.type
  else:
    return get_service_type()
  end
end

def is_service_type_LB():
  return get_dex_service_type() == SERVICE_TYPE_LOADBALANCER
end

def is_service_NodePort():
  return get_dex_service_type() == SERVICE_TYPE_NODEPORT
end

def get_dex_service_annotations():
  if globals.infrastructure_provider == "aws":
    return {"service.beta.kubernetes.io/aws-load-balancer-backend-protocol": "ssl"}
  else:
    return {}
  end
end

def validate_static_client() :
  if data.values.dex.config.staticClients and len(data.values.dex.config.staticClients) > 0:
    for client in data.values.dex.config.staticClients :
      getattr(client, "id") or assert.fail("Dex staticClients should have id")
      getattr(client, "redirectURIs") or assert.fail("Dex staticClients should have redirectURIs")
      getattr(client, "name") or assert.fail("Dex staticClients should have name")
      getattr(client, "secret") or assert.fail("Dex staticClients should have secret")
    end
  end
end

#export
values = data.values

# validate dex
validate_dex()
