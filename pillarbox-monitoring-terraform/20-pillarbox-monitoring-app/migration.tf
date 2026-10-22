# -----------------------------------
# One-time migration to 12-pillarbox-monitoring-shared
# -----------------------------------
#
# The bastion and the VPC endpoints are now owned by 12-pillarbox-monitoring-shared.
# The removed blocks drop them from this state without destroying them, and the
# import blocks adopt the endpoint ingress rules that used to be inline on
# vpc-endpoints-sg (creating them again would fail as duplicates).
#
# Delete this file once `terraform apply` has run in both the dev and prod workspaces.

removed {
  from = aws_key_pair.bastion_key
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_security_group.bastion_sg
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_instance.bastion
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_security_group.vpc_endpoints_sg
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_vpc_endpoint.ecr_api
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_vpc_endpoint.ecr_dkr
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_vpc_endpoint.cloudwatch_logs
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_vpc_endpoint.s3
  lifecycle {
    destroy = false
  }
}

import {
  for_each = {
    dispatch = aws_security_group.dispatch_task_sg.id
    transfer = aws_security_group.transfer_task_sg.id
  }

  to = aws_security_group_rule.allow_to_shared_endpoints[each.key]
  id = "${data.aws_security_group.vpc_endpoints_sg.id}_ingress_tcp_443_443_${each.value}"
}
