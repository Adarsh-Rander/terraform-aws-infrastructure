
output "ec2_public_ip" {
  description = "Public IP addresses of EC2 instances"
  value = {
    for name, instance in aws_instance.instance :
    name => instance.public_ip
  }
}
