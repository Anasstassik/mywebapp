terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.6"
    }
  }
}

provider "libvirt" {
  # Connect to the local libvirt daemon. Adjust if connecting remotely.
  uri = "qemu:///system"
}

# Use Ubuntu 24.04 Cloud Image
resource "libvirt_volume" "ubuntu_image" {
  name   = "ubuntu-24.04.qcow2"
  pool   = "default"
  source = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name      = "commoninit.iso"
  pool      = "default"
  user_data = templatefile("${path.module}/cloud_init.cfg", {
    ssh_key = file("~/.ssh/id_rsa.pub")
  })
}

# Volume for worker node
resource "libvirt_volume" "worker_vol" {
  name           = "worker-vol.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.ubuntu_image.id
  size           = 10737418240 # 10GB
}

# Worker VM (Web + Nginx)
resource "libvirt_domain" "worker" {
  name   = "lab4-worker"
  memory = "1024"
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.worker_vol.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# Volume for db node
resource "libvirt_volume" "db_vol" {
  name           = "db-vol.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.ubuntu_image.id
  size           = 10737418240 # 10GB
}

# DB VM
resource "libvirt_domain" "db" {
  name   = "lab4-db"
  memory = "1024"
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.db_vol.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

output "worker_ip" {
  value = libvirt_domain.worker.network_interface[0].addresses[0]
}

output "db_ip" {
  value = libvirt_domain.db.network_interface[0].addresses[0]
}
