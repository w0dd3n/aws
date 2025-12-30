provider "aws" {
  
  access_key = var.aws_ak_id
  secret_key = var.aws_sk_id

  region        = var.region_name
}
