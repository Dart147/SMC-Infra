variable "bucket_name" {
  description = "Globally unique name for the backup bucket"
  type        = string
}

variable "retention_days" {
  description = "Days to keep a backup object before lifecycle expiry"
  type        = number
  default     = 30
}
