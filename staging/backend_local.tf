terraform {
  backend "local" {
    path = "./tfstate/staging.tfstate"
  }
}
