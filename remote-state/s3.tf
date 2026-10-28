
resource "aws_s3_bucket" "tfstate" {
  bucket = "adarsh-tfstate-dynamobucket"
}


resource "aws_dynamodb_table" "tflock" {
  name         = "terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
