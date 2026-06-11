output "bucket_id" {
  description = "Name of the backup bucket (BACKUP_BUCKET for backup.sh)"
  value       = module.backup_bucket.bucket_id
}

output "backup_writer_access_key_id" {
  description = "Access key id for the runtime backup user (epl-1080 env)"
  value       = aws_iam_access_key.backup_writer.id
}

output "backup_writer_secret_key" {
  description = "Secret access key for the runtime backup user (epl-1080 env)"
  value       = aws_iam_access_key.backup_writer.secret
  sensitive   = true
}
