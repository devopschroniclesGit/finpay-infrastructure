variable "project_name" { type = string }
variable "db_password"  { type = string; sensitive = true }
variable "jwt_secret"   { type = string; sensitive = true }
