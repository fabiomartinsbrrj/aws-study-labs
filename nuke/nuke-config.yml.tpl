# TEMPLATE. Renderizado por nuke/run.sh (nunca edite o .rendered.yml). Valores pessoais: nuke/keep.local.json.
blocklist:
  - "000000000000"   # trava obrigatoria: conta que nunca deve ser limpa (a nossa NAO esta aqui)

regions:
  - global
  - us-east-1

accounts:
  "${ACCOUNT_ID}":
    presets:
      - protect-everywhere
      - protect-by-type

presets:
  # Filtros globais: valem para qualquer tipo de recurso que tenha a propriedade.
  protect-everywhere:
    filters:
      __global__:
        - property: "tag:persist"            # base do lab (workstation, rede, role, budget...)
          value: "true"
        - property: DefaultVPC               # VPC default e tudo dentro dela
          value: "true"
        {{GLOBAL_USERNAMES}}
        {{GLOBAL_GROUPS}}
        {{GLOBAL_ROLES}}
        - property: "tag:role:persist"       # itens filhos de uma role da base (policies, anexos)
          value: "true"
        - property: "tag:igw:persist"        # anexos do IGW da rede do lab
          value: "true"
        - property: IsDefault                # VPC default
          value: "true"
        {{GLOBAL_BUCKETS}}

  # Filtros por tipo, para o que nao tem tag nem propriedade comum.
  protect-by-type:
    filters:
      EC2KeyPair:
        {{KEY_PAIRS}}
      EC2NetworkInterface:                   # ENI da workstation (VPC do lab)
        - property: VPC
          value: "${LAB_VPC_ID}"
      S3Bucket:
        {{S3_BUCKETS}}
      BudgetsBudget:
        - "aws-lab-monthly"
        {{BUDGETS}}
      IAMUser:
        {{IAM_USERS}}
      IAMGroup:
        {{IAM_GROUPS}}
      IAMRole:
        - type: glob
          value: "AWSServiceRoleFor*"
        - "aws-lab-workstation"
        - "OrganizationAccountAccessRole"
        {{IAM_ROLES}}
      IAMPolicy:
        - "aws-lab-boundary"
      IAMInstanceProfile:
        - "aws-lab-workstation"
      # Padroes da AWS: gratis e sem uso, o nuke so daria erro neles.
      AthenaWorkGroup:
        - "primary"
      ResourceExplorer2Index:
        - property: ARN
          type: contains
          value: "resource-explorer-2"
      ResourceExplorer2View:
        - property: ARN
          type: contains
          value: "resource-explorer-2"
      AWSBackupVaultAccessPolicy:
        - "aws/efs/automatic-backup-vault"
      BedrockInferenceProfile:
        - type: glob
          value: "*"
