# Homework

**Task:**
Implement a CD pipeline on AWS with Zero Downtime deploy of a single HTTP service. We would like you to implement on AWS, in any way you want, a Zero Downtime service deployment with a Continuous Integration pipeline. Basically a setup that will deploy a new version of the service after a git push.

**Use case:**
When I push a change to git, an event is triggered and I want the new version of the service deployed within 1 minute(you should not spawn new instances, but redeploy on existing ones). I can use it without any downtime for me even during deploy procedure.

**Required toolage:**
- AWS Account
- Github (or something similar, whatever you prefer) repo with the service source code.

**Some requirements:**
- Service should be dynamic, in other words, not just a static site but something that does something simple, e.g. a fake random "stock quote" service or a counter. You can use technologies to your liking.
- When new version service is deployed, it should not respond to traffic for 15 seconds, to simulate the startup time of the service.
- When deploying the service, the new version should be in a new environment, it cannot share processes with the old version. In other words, you cannot just have an HTTP server running and simply change underlying files; the application has to restart.

---

# Homework assignment solution

I created a simple counter web app hosted on an AWS EC2 instance. For (automatic) deployment, I used AWS CodeDeploy as well as Github's Auto-Deploy integration. The steps below illustrate the exact procedure for creating the finishing solution of the assignment.

## 0. Create the Github repository
(in our case this is `Kahno/counterAppHomework`)

## 1. Create an IAM role `CodeDeployServiceRole` on AWS
Create a custom IAM policy `CodeDeployServicePolicy`.

Policy contents:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "autoscaling:PutLifecycleHook",
                "autoscaling:DeleteLifecycleHook",
                "autoscaling:RecordLifecycleActionHeartbeat",
                "autoscaling:CompleteLifecycleAction",
                "autoscaling:DescribeAutoscalingGroups",
                "autoscaling:PutInstanceInStandby",
                "autoscaling:PutInstanceInService",
                "ec2:Describe*"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
```

Edit the `CodeDeployServiceRole` Trust policy contents:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

## 2. Create an IAM role `CodeDeployInstanceRole` on AWS
Create a custom IAM policy `CodeDeployInstancePolicy`.

Policy contents:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:Get*",
                "s3:List*"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
```

## 3. Launch an EC2 instance on AWS
* Choose the Amazon Linux AMI, because it already includes the AWS Command Line Interface.
* Choose t2.micro Instance Type (standard for Free tier).
* Select the previously created `CodeDeployInstanceRole` under IAM role
* Storage settings can be left as is.
* Tag the instance with a key-value pair (in our case `Name`: `CodeDeployInstanceHomework`) for easier access.
* Configure Security Group. In our case, we have set the following:
    - Allow all inbound traffic for HTTP and HTTPS.
    - Allow my IP for SSH access.

Before launching, create an SSH key pair (in our case we set the key name as `homework`) for later usage.

## 4. Once the EC2 instance is launched, log into it and install the CodeDeploy agent.
* Select the instance from the list of instances and click Connect
* Follow the immediate instructions to connect to the instance with our previously created `homework` key.
* After logging in, input the following commands:
    - `sudo su` - (this grants root privileges for running other commands)
    - `yum -y update` - (this updates the system software to the latest version)
    - `cd /home/ec2-user` - (this moves us into the relevant directory for installing the CodeDeploy agent)
    - `aws configure`
        * input our AWS Access Key Id
        * input our AWS Access Secret Key Id
        * input our region (in our case we chose `eu-west-2`)
        * input our output (in our case we chose `json`)
    - `aws s3 cp s3://aws-codedeploy-eu-west-2/latest/install . --region eu-west-2` - (this gets the proper installation file)
    - `chmod +x ./install` - (this makes the installation file executable)
    - `./install auto` - (this installs the CodeDeploy agent)

## 5. Go to the CodeDeploy console on AWS and create a Custom Deployment.
* Set the following:
    - Application Name: `CodeDeployGithubHomework`
    - Deployment Group Name: `production`
    - Our previous EC2 instance (in our case we use the previously set key-value pair `Name`: `CodeDeployInstanceHomework`)
    - Service Role: `CodeDeployServiceRole` (created previously)
* Choose Create Application.
* Choose Deploy New Revision.
* Choose Github as the Revision Type.
* Choose Connect with Github.
* Input the repository name (in our case this is `Kahno/counterAppHomework`.
* Input the commit Id (accessible from the Github repository).
* Choose Deploy Now.

**At this point, the code from the `Kahno/counterAppHomework` can be seen running on our EC2 instance.**

## 6. Create a custom IAM policy `CodeDeployGithubAccessPolicy` on AWS
Policy contents:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "codedeploy:GetDeploymentConfig",
            "Resource": "arn:aws:codedeploy:eu-west-2:255577039930:deploymentconfig:*"
        },
        {
            "Effect": "Allow",
            "Action": "codedeploy:RegisterApplicationRevision",
            "Resource": "arn:aws:codedeploy:eu-west-2:255577039930:application:CodeDeployGithubApp"
        },
        {
            "Effect": "Allow",
            "Action": "codedeploy:GetApplicationRevision",
            "Resource": "arn:aws:codedeploy:eu-west-2:255577039930:application:CodeDeployGithubApp"
        },
        {
            "Effect": "Allow",
            "Action": "codedeploy:CreateDeployment",
            "Resource": "arn:aws:codedeploy:eu-west-2:255577039930:deploymentgroup:CodeDeployGithubApp/production"
        }
    ]
}
```

## 7. Create an IAM user.
* Set the following:
    - User name: `CodeDeployGithubUser`
    - Access type: `Programmatic access`
* Attach the previously created policy `CodeDeployGithubAccessPolicy` to the user.
* Save the Access Id and Secret Access Token for later usage.

## 8. Generate Github personal access token
* Set the following:
    - Token description: `GithubAutoDeployAccessToken`
    - Select scopes:
        * `repo:status`
        * `repo_deployment`
* Save the token for later usage.

## 9. Set up AWS CodeDeploy Integration on Github
* In the `Kahno/counterAppHomework` repository, click Settings and select Integrations & services.
* Click Add service and choose AWS CodeDeploy from the dropdown menu.
* Set the following:
    - Application name: `CodeDeployGithubHomework`
    - Deployment group: `production`
    - Aws access key: <input Access Id from Step 7>
    - Aws region: `eu-west-2`
    - Aws secret access key: <input Secret Access Token from Step 7>
    - Github token: <input token from Step 8>
    - Select the checkbox for Active
* Click Add service.

## 10. Set up Github Auto-Deployment
* In the `Kahno/counterAppHomework` repository, click Settings and select Integrations & services.
* Click Add service and choose Github Auto-Deployment from the dropdown menu.
* Set the following:
    - Github token: <input token from Step 8>
    - Environments: `production`
    - Select the checkbox for Active
* Click Add service.

**At this point, the code from the `Kahno/counterAppHomework` is getting automatically deployed to our EC2 instance whenever we push a modification.**
