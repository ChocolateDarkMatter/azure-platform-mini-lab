variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name, used in resource naming and tags."
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name, used in resource naming and tags."
  type        = string
  default     = "platform-lab"
}

variable "owner" {
  description = "Owner tag value."
  type        = string
}

variable "admin_ip" {
  description = "Your public IP address (CIDR, e.g. 203.0.113.10/32) allowed to SSH into the VM. Never leave this open to 0.0.0.0/0."
  type        = string
}

variable "admin_username" {
  description = "Admin username for the Linux VM."
  type        = string
  default     = "azureadmin"
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key file (e.g. ~/.ssh/id_rsa.pub). No password auth is configured."
  type        = string
}

variable "vm_size" {
  description = "VM size. Kept small/cheap for lab purposes."
  type        = string
  default     = "Standard_B1s"
}

variable "budget_amount" {
  description = "Monthly budget amount in USD that triggers the cost alert."
  type        = number
  default     = 20
}

variable "alert_email" {
  description = "Email address to receive Monitor alerts and the budget alert."
  type        = string
}

variable "tags" {
  description = "Common tags applied to every resource."
  type        = map(string)
  default = {
    project    = "azure-platform-mini-lab"
    purpose    = "azure learning"
    managed_by = "terraform"
  }
}
