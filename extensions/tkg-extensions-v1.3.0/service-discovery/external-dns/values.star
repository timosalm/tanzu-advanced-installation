load("@ytt:data", "data")
load("@ytt:assert", "assert")
load("/globals.star", "globals", "get_kapp_disable_wait_annotations")

def validate_external_dns():
  validate_funcs = [validate_external_dns_namespace,
                    validate_external_dns_image,
                    validate_external_dns_args]
   for validate_func in validate_funcs:
     validate_func()
   end
end

def validate_external_dns_namespace():
  data.values.externalDns.namespace or assert.fail("External-dns namespace should be provided")
end

def validate_external_dns_image():
  data.values.externalDns.image.name or assert.fail("External-dns image name should be provided")
  data.values.externalDns.image.tag or assert.fail("External-dns image tag should be provided")
  data.values.externalDns.image.repository or assert.fail("External-dns image repository should be provided")
  data.values.externalDns.image.pullPolicy or assert.fail("External-dns image pullPolicy should be provided")
end

def validate_external_dns_args():
  len(data.values.externalDns.deployment.args) or assert.fail("External-dns args should be provided")
end

#export
values = data.values

# validate external-dns data values
validate_external_dns()
