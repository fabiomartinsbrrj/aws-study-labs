# Lab: ec2-basico

Uma EC2 `t3.micro` sem porta aberta, acessada por SSM, com role sob a boundary `aws-lab-boundary`.

## O que se aprende
- Instance profile e role de EC2; permissions boundary; leitura de outputs de outra stack.

## Rodar (de dentro da workstation)
    make init STACK=labs/ec2-basico
    make apply STACK=labs/ec2-basico
    # a workstation nao tem o Session Manager plugin: rode este comando da sua maquina
    aws ssm start-session --target <instance_id-do-output>

## Provas da boundary (devem falhar com AccessDenied / UnauthorizedOperation)
    aws iam create-role --role-name teste-sem-boundary --assume-role-policy-document file://trust.json
    aws ec2 run-instances --instance-type m5.large --image-id <ami> --subnet-id <subnet>

## Limpar
    make destroy STACK=labs/ec2-basico
