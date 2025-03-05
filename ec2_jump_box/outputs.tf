output "jump_box_id" {
  description = "ID of the jump-box EC2 instance"
  value       = aws_instance.jump_box.id
}

output "jump_box_private_ip" {
  description = "Private IP of the jump-box EC2 instance"
  value       = aws_instance.jump_box.private_ip
}