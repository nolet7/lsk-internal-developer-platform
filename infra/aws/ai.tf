resource "aws_iam_role_policy" "bedrock_advisory" {
  name = "${local.name}-bedrock-readonly"
  role = aws_iam_role.task.id
  policy = jsonencode({Version="2012-10-17",Statement=[{
    Effect="Allow",Action=["bedrock:InvokeModel"],Resource=[var.bedrock_model_arn]
  }]})
}
resource "aws_iam_role_policy" "cloudwatch_triage" {
  name = "${local.name}-log-triage"
  role = aws_iam_role.task.id
  policy = jsonencode({Version="2012-10-17",Statement=[{
    Effect="Allow",Action=["logs:FilterLogEvents"],Resource=[aws_cloudwatch_log_group.app.arn]
  }]})
}
