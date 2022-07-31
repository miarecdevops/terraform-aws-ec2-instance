# EC2 instance module example

This folder contains a Terraform configuration that shows an example of how to use the `ec2_instance` module 
to install an instance in AWS account with IAM policies assigned to the instance.

This example assigns the following policy as a demonstration:

    {
        Version = "2012-10-17"
        Statement = [
        {
            Action   = "ec2:DescribeInstances"
            Effect   = "Allow"
            Resource = "*"
        },
        ]
    }

To verify if policies are assigned properly:

- Provision instance with:

    ```bash
    terraform init && terraform apply
    ```

- Login to the instance via SSH with:

    ```bash
    ssh -i priv_key.pem -o "UserKnownHostsFile=/dev/null" ubuntu@`terraform output -raw public_ip`
    ```


- Install aws cli with:

    ```
    sudo apt update && sudo apt install -y awscli
    ```

- Run command:

    ```
    aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId, Tags[?Key==`Name`].Value | [0]]' --region=us-west-2
    ```

You should see the list of instances in the AWS account, where the instance is running.

Example:

    [
        [
            [
                "i-073c1854c24c09df8",
                "ec2-instance-module-with-policies-example"
            ]
        ],
    ]


## Prerequisites

- You must have Terraform installed on your computer.
- You must have an Amazon Web Services (AWS) account.

## Quick start

Confiugre your AWS access keys as environmetn variables:

    export AWS_ACCESS_KEY_ID=(your access key id)
    export AWS_SECRET_ACCESS_KEY=(your secret access key)

Or, configure AWS credentials via AWS CLI as `default` profile.

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

    ssh -i priv_key.pem -o "UserKnownHostsFile=/dev/null" ubuntu@`terraform output -raw public_ip`
