terraform {
  required_providers {
    oci = {
      source  = "hashicorp/oci"
      version = "~> 7.26.1"
    }
  }
}

provider "oci" {
  region = "us-sanjose-1"
}

# ---------------------------------------------------------
# Data Sources
# ---------------------------------------------------------

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id = var.tenancy_ocid
  operating_system = "Canonical Ubuntu"
  operating_system_version = "22.04"
}

# ---------------------------------------------------------
# Instance
# ---------------------------------------------------------

resource "oci_core_instance" "n8n_instance" {
  display_name        = "n8n-instance"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.tenancy_ocid

  shape = "VM.Standard.E2.1.Micro"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 1
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data           = base64encode(file("cloud_init.sh"))
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  create_vnic_details {
    assign_public_ip = true
  }
}

output "n8n_public_ip" {
  value = oci_core_instance.n8n_instance.public_ip
}
