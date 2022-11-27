"""
CDK to generate the AWS lab environment for the Kubernetes Opensource Workshop
By Jason Umiker (jason.umiker@sysdig.com)
"""

from constructs import Construct
from aws_cdk import App, RemovalPolicy, Stack, Environment
from aws_cdk import (
    aws_ec2 as ec2,
    aws_iam as iam,
    aws_cloudtrail as cloudtrail
)

# Create a CloudTrail and S3 bucket to store it
class CloudTrailStack(Stack):

    def __init__(self, scope: Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Create our cloudtrail (which by default will create a new S3 bucket)
        trail = cloudtrail.Trail(self, "CloudTrail")

        # Apply a removal policy to delete everything if this stack is deleted
        trail.apply_removal_policy(RemovalPolicy.DESTROY)

# Create a Stack for our single VPC that'll host everything
class VPCStack(Stack):

    def __init__(self, scope: Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        self.vpc = ec2.Vpc(
            self, "VPC",
            # We are choosing to spread our VPC across 3 availability zones
            max_azs=3,
            # Saving some money by provisioning 1 NAT Gateway for the whole VPC instead of 3
            nat_gateways=0,
            ip_addresses=ec2.IpAddresses.cidr("10.0.0.0/16"),
            subnet_configuration=[
                # 3 x Public Subnets (1 per AZ) with 254 IPs each for our LBs, Jumpboxes and NATs
                ec2.SubnetConfiguration(
                    subnet_type=ec2.SubnetType.PUBLIC,
                    name="Public",
                    cidr_mask=24
                )
            ]
        )

class AttendeeStack(Stack):

    def __init__(self, scope: Construct, id: str, VPCStack, AttendeeIteration, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Create an IAM Role for the Jumpbox
        cluster_admin_role = iam.Role(self, "Attendee" + str(AttendeeIteration) + "Role",
            assumed_by=iam.CompositePrincipal(iam.AccountRootPrincipal(), iam.ServicePrincipal("ec2.amazonaws.com")))
        # Give our role access to connect the instance to SSM
        cluster_admin_role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("AmazonSSMManagedInstanceCore"))

        # A SecurityGroup for Jumpbox
        jumpbox_security_group = ec2.SecurityGroup(
            self, "Attendee"+str(AttendeeIteration)+"JumpboxSG",
            vpc=VPCStack.vpc,
            allow_all_outbound=True
        )

        jumpbox_security_group.add_ingress_rule(
            ec2.Peer.any_ipv4(),
            ec2.Port.tcp(30282),
            "Allow FalcosidekickUI"
        )

        # Get the Ubuntu machine image
        ubuntu_machine_image=ec2.MachineImage.from_ssm_parameter(
            parameter_name="/aws/service/canonical/ubuntu/server/focal/stable/current/amd64/hvm/ebs-gp2/ami-id",
            os=ec2.OperatingSystemType.LINUX    
        )

        # Create the EC2 instance for jumpbox
        jumpbox_instance = ec2.Instance(
            self, "Attendee"+str(AttendeeIteration)+"JumpboxInstance",
            instance_type=ec2.InstanceType("t3a.medium"),
            machine_image=ubuntu_machine_image,
            role=cluster_admin_role,
            vpc=VPCStack.vpc,
            vpc_subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PUBLIC),
            security_group=jumpbox_security_group,
            block_devices=[ec2.BlockDevice(device_name="/dev/xvda", volume=ec2.BlockDeviceVolume.ebs(16))],
            instance_name="Attendee"+str(AttendeeIteration)+"Jumpbox"
        )

        # Pre-install tools on our jumpbox
        jumpbox_instance.user_data.add_commands(
            "cd /root",
            "git clone https://github.com/jasonumiker-sysdig/kubernetes-security-demos",
            "cd /root/kubernetes-security-demos/setup-cluster",
            "./setup-microk8s.sh"
        )

        # Create an Attendee User
        # We'll have to add/reset to a random password later in a script
        attendee_user = iam.User(
            self, "Attendee"+str(AttendeeIteration)+"User",
            user_name=self.node.try_get_context("attendee_user_name") + str(AttendeeIteration)
        )

        # Give the Attendee User Read Only Access to Console
        attendee_user.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("ReadOnlyAccess")
        )

        # Give the Attendee User access to SSM Session Manager onto their jumpbox
        instance_arn = "arn:aws:ec2:"+self.region+":"+self.account+":instance/"+jumpbox_instance.instance_id
        attendee_ssm_policy_1 = {
            "Effect": "Allow",
            "Action": ["ssm:StartSession"],
            "Resource": [instance_arn]

        }
        attendee_ssm_policy_2 = {
            "Effect": "Allow",
            "Action": [
                "ssm:TerminateSession",
                "ssm:ResumeSession"
            ],
            "Resource": [
                "arn:aws:ssm:*:*:session/${aws:username}-*"
            ]
        }
        attendee_user.add_to_principal_policy(iam.PolicyStatement.from_json(attendee_ssm_policy_1))
        attendee_user.add_to_principal_policy(iam.PolicyStatement.from_json(attendee_ssm_policy_2))

app = App()
# Get account and region from cdk.json
account = app.node.try_get_context("account")
region = app.node.try_get_context("region")
# Create our single shared CloudTrail Stack
cloudtrail_stack = CloudTrailStack(app, "CloudTrailStack", env=Environment(account=account, region=region))
# Create our single shared VPC
vpc_stack = VPCStack(app, "VPCStack", env=Environment(account=account, region=region))
# Loop through creating all our Attendee stacks
attendee = 1
while attendee <= app.node.try_get_context("num_of_attendees"):
    attendee_stack = AttendeeStack(app, "AttendeeStack"+str(attendee), VPCStack=vpc_stack, AttendeeIteration=attendee, env=Environment(account=account, region=region))
    attendee = attendee + 1
app.synth()
