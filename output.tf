

output "ec2_public_ip" {
  value = [
    for instances in aws_instance.instance : instances.public_ip
  ]
}

