variable "public_subnet_cidrs" {
  type    = list(any)
  default = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
}

variable "private_subnet_cidrs" {
  type    = list(any)
  default = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]
}
