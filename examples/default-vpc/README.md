# EC2 instance module example

This folder contains a Terraform configuration that shows an example of how to use the `ec2_instance` module 
to install an instance in AWS account using a default VPC.

## Prerequisites

- You must have Terraform installed on your computer.
- You must have an Amazon Web Services (AWS) account.

## Quick start

Configure your AWS access keys as environment variables:

    export AWS_ACCESS_KEY_ID=(your access key id)
    export AWS_SECRET_ACCESS_KEY=(your secret access key)

Or, use a named profile from the AWS CLI configuration:

    export TF_VAR_aws_profile=(your profile name)

When no profile is given, the provider uses the default AWS credential chain.

Deploy the code:

    terraform init
    terraform apply

Clean up when you're done:

    terraform destroy

This configuration will deploy EC2 instance in a default VPC.

## How to connect to EC2 instance via SSH

To connect to the instance via SSH, you need to know:

- SSH private key
- Public IP address of the instance

This configuration generates SSH key pair and installs it on EC2 instance.

A private key is saved into `./priv_key.pem` file in the current direction. you need to use this key to connect to the Bastion instance via SSH.

To retieve a public IP address of the instance, run:

    terraform output public_ip

Connect to instance via SSH:

    ssh -i priv_key.pem ubuntu@1.2.3.4

Where `1.2.3.4` is a public IP of the instance.

Alternatively, use the following command to automatically retrieve a public ip and open SSh in one step:

    ssh -i priv_key.pem ubuntu@`terraform output -raw public_ip`
