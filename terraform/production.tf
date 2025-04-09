resource "proxmox_vm_qemu" "test" {
  vmid = 300
  name        = "test"
  target_node = "PVE2R0"

  clone = "SRV-IMP-2012-R2"
  full_clone = true
  bios = "ovmf"
  agent = 1
  scsihw = "virtio-scsi-single"
  os_type = "ubuntu"
  cpu_type = "host"
  sockets = 1
  cores = 1
  memory = 2048
  disks {
       scsi {
           scsi0 {
                disk {
		    size = "30G"
		    storage = "local"
                    format = "qcow2"
        }
      }
    }
  }
}
