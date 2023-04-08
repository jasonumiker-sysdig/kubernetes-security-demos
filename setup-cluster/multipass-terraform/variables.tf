variable "name" {
  description = "The name of our VM"
  type        = string
  default     = "microk8s-vm"
}

variable "memory" {
  description = "Memory/RAM to allocate in GBs"
  type        = number
  default     = 4
}

variable "storage" {
  description = "Disk space to allocate in GBs"
  type        = number
  default     = 10
}

variable "cores" {
  description = "Number of CPUs to allocate"
  type        = number
  default     = 2
}

variable "userdata" {
  description = "Cloud-init Script"
  type        = string
  default     = "../cloud-init.yaml"
}

variable "image" {
  description = "The multipass image to launch"
  type        = string
  default     = "22.04"
}