
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "ap-southeast-2"
}

module "network" {
  source = "github.com/sijockappen/network"
}

resource "aws_iam_instance_profile" "elbk_profile" {
  name = "elbk_profile"
  role = aws_iam_role.role.name
}

data "aws_iam_policy_document" "elbk_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "role" {
  name                = "elbk_role"
  path                = "/"
  assume_role_policy  = data.aws_iam_policy_document.elbk_role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier", "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier", "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"]
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "devops-kappen.click"
  validation_method = "DNS"

}

resource "aws_elastic_beanstalk_application" "elbk_app" {
  name        = "ELBKApplication"
  description = "ELBK Application"
}

resource "aws_elastic_beanstalk_environment" "elbk_env" {
  name                = "elbkenv"
  application         = aws_elastic_beanstalk_application.elbk_app.name
  solution_stack_name = "64bit Amazon Linux 2 v3.5.7 running Docker"

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = module.network.vpc_id
  }

  setting {
    namespace = "aws:ec2:instances"
    name      = "EnableSpot"
    value     = true
  }

  setting {
    namespace = "aws:ec2:instances"
    name      = "InstanceTypes"
    value     = "t2.micro, t3.micro"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", module.network.private_subnets)
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "false"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBScheme"
    value     = "public"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = join(",", module.network.public_subnets)
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.elbk_profile.name
  }

  setting {
    namespace = "aws:elb:listener:443"
    name      = "SSLCertificateId"
    value     = aws_acm_certificate.cert.arn
  }

  setting {
    namespace = "aws:elb:listener:443"
    name      = "InstancePort"
    value     = "80"
  }

  setting {
    namespace = "aws:elb:listener:443"
    name      = "InstanceProtocol"
    value     = "HTTP"
  }

  setting {
    namespace = "aws:elb:listener:443"
    name      = "ListenerProtocol"
    value     = "HTTPS"
  }

}

resource "aws_route53_record" "www" {

  depends_on = [
    aws_elastic_beanstalk_environment.elbk_env
  ]

  zone_id = "Z0535593URHWUZLA596X"
  name    = "devops-kappen.click"
  type    = "A"

  alias {
    name = aws_elastic_beanstalk_environment.elbk_env.cname
    # https://docs.aws.amazon.com/general/latest/gr/elasticbeanstalk.html
    zone_id                = "Z2PCDNR3VC2G1N"
    evaluate_target_health = true
  }
}
