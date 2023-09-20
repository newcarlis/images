terraform {
  required_providers {
    oci = { source = "chainguard-dev/oci" }
  }
}

variable "target_repository" {
  description = "The docker repo into which the image and attestations should be published."
}

module "dev" { source = "../../tflib/dev-subvariant" }

resource "random_pet" "suffix" {}

module "test-latest" {
  source = "./tests"
  digests = {
    proxy    = module.proxy.image_ref
    pilot    = module.pilot.image_ref
    operator = module.operator.image_ref
  }
  namespace = "istio-system-${random_pet.suffix.id}"
}

resource "oci_tag" "latest" {
  depends_on = [module.test-latest]
  for_each = {
    "proxy" : module.proxy.image_ref,
    "pilot" : module.pilot.image_ref,
    "operator" : module.operator.image_ref,
  }
  digest_ref = each.value
  tag        = "latest"
}

resource "oci_tag" "latest-dev" {
  depends_on = [module.test-latest]
  for_each = {
    "proxy" : module.proxy-dev.image_ref,
    "pilot" : module.pilot-dev.image_ref,
    "operator" : module.operator-dev.image_ref,
  }
  digest_ref = each.value
  tag        = "latest-dev"
}
