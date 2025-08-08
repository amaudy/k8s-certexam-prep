terraform {
  required_version = ">= 1.4.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

# Provider will read the token from the DIGITALOCEAN_TOKEN environment variable
provider "digitalocean" {}


