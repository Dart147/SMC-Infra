module "backup_bucket" {
  source = "./modules/backup-bucket"

  bucket_name    = var.bucket_name
  retention_days = var.retention_days
}

# PutObject on this bucket's objects and nothing else (a leaked key can append backups but never read or destroy them).
resource "aws_iam_user" "backup_writer" {
  name = "smc-backup-writer"
}

resource "aws_iam_user_policy" "backup_writer_put_only" {
  name = "s3-putobject-backup-bucket-only"
  user = aws_iam_user.backup_writer.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PutBackupObjectsOnly"
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${module.backup_bucket.bucket_arn}/*"
      }
    ]
  })
}

resource "aws_iam_access_key" "backup_writer" {
  user = aws_iam_user.backup_writer.name
}
