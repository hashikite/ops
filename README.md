# Ops

Retained Hashikite demo data and DNS zone, managed with Terraform 0.12.26.

The app and ops Buildkite pipelines were deleted. Do not restore them.
The demo's compute, load balancer, certificate, IAM roles and VPC are being
retired. The deleted apex A record must not be recreated.

## Retained resources

- `ops.production.hashikite.net`, including every Terraform state version.
- ECR repositories `app` and `buildkite-agent-ops`, including their images.
- CloudWatch log groups `/app` and `/ops/buildkite-agent`.
- The `hashikite.com` hosted zone. The separately owned `hashikite.net` zone
  and both domain registrations are unchanged.
- GitHub repositories and webhooks remain in GitHub but are no longer managed
  by this state. Existing SSM parameters are untouched.

The former NAT address `35.172.50.5` belongs to
[GHES integration Terraform](https://github.com/buildkite/aws-buildkite-integration-test/pull/54).
The other two idle EIPs were released after
[NAT retirement](https://github.com/hashikite/ops/pull/2).

## Retirement deployment

Use account `542948915641`, region `us-east-1`. Keep state and saved plans
private. No Buildkite pipeline remains to deploy this repository.

Before planning against the remote backend, preserve its current S3 version
and remove only the following obsolete non-AWS ownership entries with
Terraform 0.12.26 `state rm` (this must not delete the GitHub objects):

```text
buildkite_pipeline.app
buildkite_pipeline.ops
github_repository.app
github_repository.ops
github_repository_webhook.app-buildkite
github_repository_webhook.ops-buildkite
```

Remove the three obsolete SSM data-source entries from state as well:
`data.aws_ssm_parameter.github-token`,
`data.aws_ssm_parameter.buildkite-api-token`, and
`data.aws_ssm_parameter.buildkite-agent-ops-token`.
These are reads, not SSM parameter resources; the parameters must remain.
Verify that all other managed state entries are unchanged. The earlier EIP
migration already removed the EIP and absent NAT entries; do not import them
back into this state.

`AppTaskRole` also has an existing, untracked attachment to
`arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy`.
Import it as `aws_iam_role_policy_attachment.app-ecs` before teardown.
Temporarily restore its original role, attachment and trust-policy declarations
from before this change, import using ID
`AppTaskRole/arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy`,
and refresh that attachment to record its dependency on `aws_iam_role.app`.
Then remove those temporary declarations again. This schedules the detach
before role deletion without changing or deleting the shared AWS policy.

Review a fresh saved plan before applying. It must only destroy dedicated
Hashikite demo resources, without changing retained resources or touching
GHES. A local-copy rehearsal is not the deployable remote-backend plan.
Apply only after review and outside the GHES cutover critical section.
