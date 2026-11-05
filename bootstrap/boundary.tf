data "aws_caller_identity" "current" {}

locals {
  account_id    = data.aws_caller_identity.current.account_id
  role_name     = "aws-lab-workstation"
  boundary_name = "aws-lab-boundary"
  role_arn      = "arn:aws:iam::${local.account_id}:role/${local.role_name}"
  boundary_arn  = "arn:aws:iam::${local.account_id}:policy/${local.boundary_name}"
  profile_arn   = "arn:aws:iam::${local.account_id}:instance-profile/${local.role_name}"
  lab_roles     = "arn:aws:iam::${local.account_id}:role/aws-lab-*"
  lab_policies  = "arn:aws:iam::${local.account_id}:policy/aws-lab-*"
  state_bucket  = "arn:aws:s3:::${var.state_bucket}"
}

# O que a workstation (e as roles criadas por ela) pode fazer. Serve de permissao e de teto.
data "aws_iam_policy_document" "allow" {
  statement {
    sid = "StudyServices"
    actions = [
      "ec2:*", "ssm:*", "ssmmessages:*", "ec2messages:*",
      "s3:*", "cloudwatch:*", "logs:*", "iam:*", "sts:*",
      "budgets:ViewBudget", "budgets:Describe*",
    ]
    resources = ["*"]
  }
  statement {
    sid = "ReadOnlyEverywhere"
    actions = [
      "elasticloadbalancing:Describe*", "autoscaling:Describe*", "cloudformation:Describe*",
      "cloudformation:List*", "kms:Describe*", "kms:List*", "route53:List*", "sns:List*", "sqs:List*",
      "ce:Get*", "pricing:*", "tag:Get*", "resource-groups:List*",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "deny" {
  statement {
    sid         = "OnlyUsEast1"
    effect      = "Deny"
    not_actions = ["iam:*", "sts:*", "s3:*", "budgets:*", "route53:*", "cloudfront:*", "support:*", "organizations:*"]
    resources   = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = ["us-east-1"]
    }
  }
  statement {
    sid       = "OnlyCheapInstanceTypes"
    effect    = "Deny"
    actions   = ["ec2:RunInstances"]
    resources = ["arn:aws:ec2:*:*:instance/*"]
    condition {
      test     = "StringNotLike"
      variable = "ec2:InstanceType"
      values   = ["t3.*", "t4g.*"]
    }
  }
  statement {
    sid       = "NoExpensiveServices"
    effect    = "Deny"
    actions   = ["ec2:CreateNatGateway", "eks:*", "rds:*"]
    resources = ["*"]
  }
  statement {
    sid    = "ProtectSelf"
    effect = "Deny"
    actions = [
      "iam:DeleteRole", "iam:UpdateAssumeRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:CreatePolicyVersion", "iam:DeletePolicy",
      "iam:DeletePolicyVersion", "iam:SetDefaultPolicyVersion", "iam:TagRole", "iam:UntagRole",
      "iam:UpdateRole", "iam:PassRole", "iam:TagPolicy", "iam:UntagPolicy",
      "iam:RemoveRoleFromInstanceProfile", "iam:AddRoleToInstanceProfile", "iam:DeleteInstanceProfile",
      "iam:TagInstanceProfile", "iam:UntagInstanceProfile",
    ]
    resources = [local.role_arn, local.boundary_arn, local.profile_arn]
  }
  statement {
    sid       = "ProtectPersistTag"
    effect    = "Deny"
    actions   = ["ec2:CreateTags", "ec2:DeleteTags"]
    resources = ["*"]
    condition {
      test     = "ForAnyValue:StringEqualsIgnoreCase"
      variable = "aws:TagKeys"
      values   = ["persist"]
    }
  }
  # project so pode ser definido na criacao do recurso (ec2:CreateAction presente).
  statement {
    sid       = "ProjectTagAfterCreate"
    effect    = "Deny"
    actions   = ["ec2:CreateTags", "ec2:DeleteTags"]
    resources = ["*"]
    condition {
      test     = "ForAnyValue:StringEqualsIgnoreCase"
      variable = "aws:TagKeys"
      values   = ["project"]
    }
    condition {
      test     = "Null"
      variable = "ec2:CreateAction"
      values   = ["true"]
    }
  }
  # DeleteTags sem lista de chaves apaga TODAS as tags; sem aws:TagKeys a condicao acima nao casa.
  statement {
    sid       = "DeleteTagsNeedKeys"
    effect    = "Deny"
    actions   = ["ec2:DeleteTags"]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:TagKeys"
      values   = ["true"]
    }
  }
  statement {
    sid    = "NoIamUsersGroups"
    effect = "Deny"
    actions = [
      "iam:CreateLoginProfile", "iam:UpdateLoginProfile", "iam:EnableMFADevice", "iam:AttachUserPolicy",
      "iam:PutUserPolicy", "iam:AddUserToGroup", "iam:UpdateAccessKey", "iam:CreateServiceSpecificCredential",
      "iam:AttachGroupPolicy", "iam:PutGroupPolicy", "iam:UpdateUser", "iam:DeleteUser",
      "iam:PutUserPermissionsBoundary", "iam:DeleteUserPermissionsBoundary", "iam:DeactivateMFADevice",
      "iam:CreateVirtualMFADevice", "iam:ChangePassword", "iam:Upload*",
      "iam:UpdateAccountPasswordPolicy", "iam:DetachUserPolicy", "iam:DeleteUserPolicy", "iam:RemoveUserFromGroup",
      "iam:CreateGroup", "iam:UpdateGroup", "iam:DeleteGroup", "iam:DetachGroupPolicy", "iam:DeleteGroupPolicy",
      "iam:CreateOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:AddClientIDToOpenIDConnectProvider", "iam:CreateSAMLProvider", "iam:UpdateSAMLProvider",
    ]
    resources = ["*"]
  }
  statement {
    sid           = "RoleChangeLabOnly"
    effect        = "Deny"
    actions       = ["iam:PassRole", "iam:AttachRolePolicy", "iam:PutRolePolicy", "iam:UpdateAssumeRolePolicy", "sts:AssumeRole"]
    not_resources = [local.lab_roles]
  }
  statement {
    sid           = "DestructiveRoleLabOnly"
    effect        = "Deny"
    actions       = ["iam:DeleteRole", "iam:DeleteRolePolicy", "iam:DetachRolePolicy", "iam:UpdateRole", "iam:UntagRole", "iam:TagRole", "iam:UpdateRoleDescription", "iam:DeleteServiceLinkedRole"]
    not_resources = [local.lab_roles]
  }
  statement {
    sid           = "PolicyVerLabOnly"
    effect        = "Deny"
    actions       = ["iam:CreatePolicyVersion", "iam:SetDefaultPolicyVersion", "iam:DeletePolicy", "iam:DeletePolicyVersion"]
    not_resources = [local.lab_policies]
  }
  statement {
    sid       = "SsmOnlyOnLabInstances"
    effect    = "Deny"
    actions   = ["ssm:SendCommand", "ssm:StartSession"]
    resources = ["arn:aws:ec2:*:*:instance/*"]
    condition {
      test     = "StringNotEquals"
      variable = "ssm:resourceTag/project"
      values   = ["aws-lab"]
    }
  }
  statement {
    sid    = "NoSecretOrDataReads"
    effect = "Deny"
    actions = [
      "secretsmanager:GetSecretValue", "lambda:GetFunction", "dynamodb:GetItem", "dynamodb:BatchGetItem",
      "dynamodb:Query", "dynamodb:Scan",
    ]
    resources = ["*"]
  }
  statement {
    sid    = "NoInstanceTypeBypass"
    effect = "Deny"
    actions = [
      "ec2:Purchase*", "ec2:AllocateHosts", "ec2:ModifyInstancePlacement", "ec2:RunScheduledInstances",
      "ec2:CreateCapacityReservation", "ec2:CreateFleet", "ec2:RequestSpotFleet", "ec2:RequestSpotInstances",
    ]
    resources = ["*"]
  }
  # Fail-closed: so atributos conhecidos e seguros; mudar o tipo (instanceType) fica negado.
  statement {
    sid       = "InstAttrAllowlist"
    effect    = "Deny"
    actions   = ["ec2:ModifyInstanceAttribute"]
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "ec2:Attribute"
      values   = ["groupSet", "disableApiTermination", "sourceDestCheck", "instanceInitiatedShutdownBehavior"]
    }
  }
  statement {
    sid    = "StateBucketTamper"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket", "s3:PutBucket*", "s3:DeleteBucketPolicy", "s3:PutLifecycleConfiguration",
      "s3:PutReplicationConfiguration", "s3:PutEncryptionConfiguration",
    ]
    resources = [local.state_bucket]
  }
  statement {
    sid       = "StateObjectAcls"
    effect    = "Deny"
    actions   = ["s3:PutObjectAcl", "s3:PutObjectVersionAcl"]
    resources = ["${local.state_bucket}/*"]
  }
  statement {
    sid       = "StateObjRO"
    effect    = "Deny"
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:DeleteObjectVersion"]
    resources = ["${local.state_bucket}/bootstrap/*", "${local.state_bucket}/network/*", "${local.state_bucket}/state-backend/*"]
  }
  statement {
    sid       = "NoVersionPurge"
    effect    = "Deny"
    actions   = ["s3:DeleteObjectVersion"]
    resources = ["${local.state_bucket}/*"]
  }
  statement {
    sid       = "NewRoleBoundary"
    effect    = "Deny"
    actions   = ["iam:CreateRole", "iam:PutRolePermissionsBoundary"]
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.boundary_arn]
    }
  }
  statement {
    sid       = "BoundaryKeep"
    effect    = "Deny"
    actions   = ["iam:DeleteRolePermissionsBoundary", "iam:CreateUser", "iam:CreateAccessKey"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "boundary" {
  source_policy_documents = [
    data.aws_iam_policy_document.allow.json,
    data.aws_iam_policy_document.deny.json,
  ]
}

resource "aws_iam_policy" "boundary" {
  name   = local.boundary_name
  policy = data.aws_iam_policy_document.boundary.json
  tags   = { persist = "true" }
}
