output "elb_target_group_arn" {
  value = aws_lb_target_group.project-target-group.arn
}

output "elb_load_balancer_dns_name" {
  value = aws_lb.project-lb.dns_name
}

output "elb_zone_id" {
  value = aws_lb.project-lb.zone_id
}