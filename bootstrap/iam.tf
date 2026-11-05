data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "workstation" {
  name                 = local.role_name
  assume_role_policy   = data.aws_iam_policy_document.ec2_trust.json
  permissions_boundary = aws_iam_policy.boundary.arn
  tags                 = { persist = "true" }
}

resource "aws_iam_role_policy" "workstation" {
  name   = "study-permissions"
  role   = aws_iam_role.workstation.id
  policy = data.aws_iam_policy_document.allow.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.workstation.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "workstation" {
  name = local.role_name
  role = aws_iam_role.workstation.name
  tags = { persist = "true" }
}
