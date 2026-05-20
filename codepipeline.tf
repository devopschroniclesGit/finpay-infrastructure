# ── S3 — Pipeline Artifacts ───────────────────────────────────────────────────

resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "${var.app_name}-pipeline-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  bucket                  = aws_s3_bucket.pipeline_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── CodeBuild Project ─────────────────────────────────────────────────────────

resource "aws_codebuild_project" "finpay" {
  name          = "${var.app_name}-codebuild"
  description   = "Build Docker image, push to ECR, generate Dockerrun.aws.json"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 30

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type     = "S3"
    location = "${aws_s3_bucket.pipeline_artifacts.bucket}/npm-cache"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true # required for Docker builds

    environment_variable {
      name  = "ECR"
      value = aws_ecr_repository.finpay.repository_url
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-BUILDSPEC
      version: 0.2

      env:
        variables:
          ECR: "${aws_ecr_repository.finpay.repository_url}"

      cache:
        paths:
          - '/root/.npm/**/*'
          - 'node_modules/**/*'
          - 'client/node_modules/**/*'

      phases:
        install:
          runtime-versions:
            nodejs: 20
        pre_build:
          commands:
            - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
            - IMAGE_TAG=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c1-8)
            - echo "Image tag is $IMAGE_TAG"
            - npm ci
            - npm run lint
        build:
          commands:
            - docker build -t $ECR:$IMAGE_TAG .
            - docker tag $ECR:$IMAGE_TAG $ECR:latest
        post_build:
          commands:
            - docker push $ECR:$IMAGE_TAG
            - docker push $ECR:latest
            - python3 -c "import json; f=open('Dockerrun.aws.json','w'); json.dump({'AWSEBDockerrunVersion':'1','Image':{'Name':'$ECR:latest','Update':'true'},'Ports':[{'ContainerPort':3000,'HostPort':80}]},f); f.close(); print('File written')"
            - cat Dockerrun.aws.json
            - ls -la

      artifacts:
        files:
          - Dockerrun.aws.json
    BUILDSPEC
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.app_name}"
      stream_name = "build"
    }
  }
}

# ── CodePipeline ──────────────────────────────────────────────────────────────

resource "aws_codepipeline" "finpay" {
  name     = "${var.app_name}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  pipeline_type  = "V2"
  execution_mode = "QUEUED"

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  # ── Stage 1: Source ────────────────────────────────────────────────────────
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        ConnectionArn        = var.github_connection_arn
        FullRepositoryId     = var.github_repo
        BranchName           = var.github_branch
        OutputArtifactFormat = "CODE_ZIP"
        DetectChanges        = "true"
      }
    }
  }

  # ── Stage 2: Build ─────────────────────────────────────────────────────────
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = aws_codebuild_project.finpay.name
      }
    }
  }

  # ── Stage 3: Deploy ────────────────────────────────────────────────────────
  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ElasticBeanstalk"
      version         = "1"
      input_artifacts = ["BuildArtifact"]

      configuration = {
        ApplicationName = aws_elastic_beanstalk_application.finpay.name
        EnvironmentName = aws_elastic_beanstalk_environment.finpay_production.name
      }
    }
  }
}
