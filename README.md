# Lab M4.10 - Terraform Git Workflows

**Course:** Cloud Engineering Bootcamp - Week 4 (Infrastructure as Code)
**Repository:** https://github.com/Draian123/ce-lab-terraform-workflows

Running `terraform apply` from a laptop works for learning; teams run Terraform
through CI. This repo sets up that workflow: feature branches, automated
validation, and `terraform plan` output posted to every pull request.

## Workflow

1. Create a feature branch off `main`
2. Make infrastructure changes
3. Push and open a PR
4. GitHub Actions runs format check, init, validate, plan
5. Review the plan output posted as a PR comment
6. Merge to `main`

`main` is never edited directly — every infrastructure change is reviewed as a
plan diff before it lands.

## CI/CD Pipeline

`.github/workflows/terraform.yml` runs on pushes to `main` and on all PRs:

| Step | Purpose | Fails the build? |
|------|---------|------------------|
| `terraform fmt -check -recursive` | Consistent code style | No — reported in the PR comment |
| `terraform init -backend=false` | Download providers | Yes |
| `terraform validate` | Catch syntax and type errors | Yes |
| `terraform plan` | Show proposed changes (PRs only) | No — reported in the PR comment |
| Post Plan to PR | Comment the plan on the pull request | Yes |

`fmt` and `plan` use `continue-on-error: true` so the plan comment is always
posted, even when a step fails. Their status shows up in the comment header, so
a reviewer sees the failure rather than the job silently going red before
commenting.

### Credentials

The plan step reads `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from
repository secrets. These belong to a dedicated IAM user
(`github-actions-tf-workflows`) with only `AmazonS3ReadOnlyAccess` attached —
enough to plan, not enough to change anything. CI never gets credentials that
can modify infrastructure.

> A production setup would use GitHub's OIDC provider to assume a short-lived
> IAM role instead of storing long-lived access keys as secrets at all.

## Infrastructure

A deliberately small S3 example, so the focus stays on the workflow:

- `aws_s3_bucket.demo` — the bucket
- `aws_s3_bucket_versioning.demo` — versioning enabled
- `aws_s3_bucket_server_side_encryption_configuration.demo` — AES256 at rest
- `aws_s3_bucket_public_access_block.demo` — all four public access blocks on

The last two were added through the feature branch
`feature/add-bucket-encryption` to demonstrate the review workflow: the PR plan
showed `2 to add` growing to `4 to add`, with no changes to existing resources.

## Repository Structure

```
├── .github/
│   ├── workflows/terraform.yml     CI pipeline
│   └── pull_request_template.md    Checklist for infra PRs
├── .gitignore                      Excludes state, tfvars, .terraform/
├── main.tf                         Provider + S3 resources
├── variables.tf                    region, project_name, environment
├── outputs.tf                      bucket_name, bucket_arn
└── README.md
```

## What `.gitignore` protects

`*.tfstate` and `*.tfstate.*` are the important ones — state files contain
resource attributes in plaintext, including values marked sensitive. `*.tfvars`
is excluded for the same reason, with `!terraform.tfvars.example` allowed
through so the expected variables are still documented. `.terraform/` is just
downloaded provider binaries and would bloat the repo.

## Local Development

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

Run these before pushing — the same three checks run in CI, so catching them
locally saves a round trip.

## Notes

The `Post Plan to PR` step passes the plan through an `env:` variable rather
than interpolating `${{ steps.plan.outputs.stdout }}` straight into the
JavaScript template literal. Direct interpolation breaks the script if the plan
output ever contains a backtick or `${`, and would let plan content execute as
code in the Actions runner.
