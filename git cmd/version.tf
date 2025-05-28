Terraform {
 required_providers{
  aws = {
   source = "Hashicorp/aws"
   version = "~> 4.0"}}}


   provider "aws" {
    region = "us-east-1"
    profile = "default"}


    Backend "s3" {
     bucket = ""
     Key    =  ""
     region = "us-east-1"
     }
