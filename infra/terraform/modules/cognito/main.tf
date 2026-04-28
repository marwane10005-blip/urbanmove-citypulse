resource "aws_cognito_user_pool" "this" {
  name                     = "${var.name_prefix}-users"
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 12
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 3
  }

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  mfa_configuration = var.mfa_configuration

  dynamic "software_token_mfa_configuration" {
    for_each = var.mfa_configuration == "OFF" ? [] : [1]
    content {
      enabled = true
    }
  }

  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    developer_only_attribute = false
    string_attribute_constraints {
      min_length = 5
      max_length = 256
    }
  }

  schema {
    name                     = "fleet_id"
    attribute_data_type      = "String"
    required                 = false
    mutable                  = true
    developer_only_attribute = false
    string_attribute_constraints {
      min_length = 1
      max_length = 64
    }
  }

  username_attributes = ["email"]

  user_pool_add_ons {
    advanced_security_mode = "AUDIT"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-users"
  })
}

resource "aws_cognito_user_group" "fleet_operator" {
  name         = "fleet-operator"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Operators who supervise live fleet + acknowledge alerts"
  precedence   = 10
}

resource "aws_cognito_user_group" "analyst" {
  name         = "analyst"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Read-only access to analytics dashboards and exports"
  precedence   = 20
}

resource "aws_cognito_user_pool_client" "dashboard" {
  name         = "${var.name_prefix}-dashboard"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  callback_urls                        = var.callback_urls
  logout_urls                          = var.logout_urls
  supported_identity_providers         = ["COGNITO"]

  access_token_validity  = var.access_token_validity_minutes
  id_token_validity      = var.access_token_validity_minutes
  refresh_token_validity = var.refresh_token_validity_days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  read_attributes = [
    "email",
    "email_verified",
    "custom:fleet_id",
  ]

  write_attributes = [
    "email",
    "custom:fleet_id",
  ]

  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true
}

data "aws_caller_identity" "current" {}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = "${var.name_prefix}-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.this.id
}
