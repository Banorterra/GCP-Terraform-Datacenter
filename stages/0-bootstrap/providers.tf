provider "google" {
  region = var.primary_region
}

provider "google-beta" {
  region = var.primary_region
}
