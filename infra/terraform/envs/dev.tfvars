project     = "urbanmove"
environment = "dev"
aws_region  = "eu-west-3"
azs         = ["eu-west-3a", "eu-west-3b"]

vpc_cidr_prod = "10.10.0.0/16"
vpc_cidr_ml   = "10.20.0.0/16"

expensive_on = true
demo_mode    = false

eks_version           = "1.31"
aurora_engine_version = "16.13"

cost_budget_usd = 70
admin_email     = "ali.h.cherri@gmail.com"
