#!/usr/bin/env python3
"""Renderiza nuke-config.yml.tpl -> .rendered.yml.
Env: ACCOUNT_ID, STATE_BUCKET, LAB_VPC_ID, ADMIN_USER. Le tambem key_name de bootstrap/terraform.tfvars (key pair da workstation e sempre protegido).
Opcional: nuke/keep.local.json
  {"users": [], "groups": [], "roles": [], "buckets": [], "budgets": [], "key_pairs": []}
"""
import json, os, re, sys
here = os.path.dirname(os.path.abspath(__file__))
keep = {"users": [], "groups": [], "roles": [], "buckets": [], "budgets": [], "key_pairs": []}
kp = os.path.join(here, "keep.local.json")
if os.path.exists(kp):
    keep.update(json.load(open(kp)))
tf = os.path.join(here, "..", "bootstrap", "terraform.tfvars")
if os.path.exists(tf):
    m = re.search(r'^\s*key_name\s*=\s*"([^"]+)"', open(tf).read(), re.M)
    if m and m.group(1) not in keep["key_pairs"]:
        keep["key_pairs"].append(m.group(1))
env = {k: os.environ[k] for k in ("ACCOUNT_ID", "STATE_BUCKET", "LAB_VPC_ID", "ADMIN_USER")}
users = [env["ADMIN_USER"]] + keep["users"]
buckets = [env["STATE_BUCKET"]] + keep["buckets"]
blocks = {
    "GLOBAL_USERNAMES": [f'- property: UserName\n  value: "{u}"' for u in users],
    "GLOBAL_BUCKETS": [f'- property: Bucket\n  value: "{b}"' for b in buckets],
    "GLOBAL_GROUPS": [f'- property: GroupName\n  value: "{g}"' for g in keep["groups"]] or ['- property: GroupName\n  value: "__nenhum__"'],
    "GLOBAL_ROLES": [f'- property: RoleName\n  value: "{r}"' for r in keep["roles"]] or ['- property: RoleName\n  value: "__nenhum__"'],
    "IAM_GROUPS": [f'- "{g}"' for g in keep["groups"]] or ['- "__nenhum__"'],
    "IAM_ROLES": [f'- "{r}"' for r in keep["roles"]],
    "KEY_PAIRS": [f'- "{k}"' for k in keep["key_pairs"]] or ['- "__nenhum__"'],
    "S3_BUCKETS": [f'- "s3://{b}"' for b in buckets],
    "BUDGETS": [f'- "{b}"' for b in keep["budgets"]],
    "IAM_USERS": [f'- "{u}"' for u in users],
}
out = []
for line in open(os.path.join(here, "nuke-config.yml.tpl")).read().splitlines():
    m = re.fullmatch(r"(\s*)\{\{(\w+)\}\}", line)
    if m:
        for item in blocks[m.group(2)]:
            out += [m.group(1) + l for l in item.splitlines()]
    else:
        out.append(line)
text = "\n".join(out) + "\n"
for k, v in env.items():
    text = text.replace("${%s}" % k, v)
open(os.path.join(here, ".rendered.yml"), "w").write(text)
