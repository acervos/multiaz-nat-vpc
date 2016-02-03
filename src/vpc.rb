class RuleNumber
  def initialize
    @start = 100
  end

  def generate
    @start = @start.next
  end
end

rule_number = RuleNumber.new

CloudFormation do
  Description "A multi AZ VPC with 6 subnets and NATS for private traffic"

  Mapping("NATAMI", {
    "us-east-1" => {
      "hvm_ebs" => "ami-b0210ed8",
      "hvm_gp2" => "ami-303b1458",
      "pv_ebs"  => "ami-c02b04a8"
    },
    "us-west-2" => {
      "hvm_ebs" => "ami-77a4b816",
      "hvm_gp2" => "ami-69ae8259",
      "pv_ebs"  => "ami-2dae821d"
    },
    "us-west-1" => {
      "hvm_ebs" => "ami-ef1a718f",
      "hvm_gp2" => "ami-7da94839",
      "pv_ebs"  => "ami-67a54423"
    },
    "eu-west-1" => {
      "hvm_ebs" => "ami-c0993ab3",
      "hvm_gp2" => "ami-6975eb1e",
      "pv_ebs"  => "ami-cb7de3bc"
    },
    "eu-central-1" => {
      "hvm_ebs" => "ami-0b322e67",
      "hvm_gp2" => "ami-46073a5b",
      "pv_ebs"  => "ami-3604392b"
    },
    "ap-southeast-1" => {
      "hvm_ebs" => "ami-e2fc3f81",
      "hvm_gp2" => "ami-b49dace6",
      "pv_ebs"  => "ami-b098a9e2"
    },
    "ap-northeast-1" => {
      "hvm_ebs" => "ami-f885ae96",
      "hvm_gp2" => "ami-03cf3903",
      "pv_ebs"  => "ami-c7e016c7"
    },
    "ap-southeast-2" => {
      "hvm_ebs" => "ami-e3217a80",
      "hvm_gp2" => "ami-e7ee9edd",
      "pv_ebs"  => "ami-0fed9d35"
    },
    "ap-northeast-2" => {
      "hvm_ebs" => "ami-4118d72f",
      "hvm_gp2" => "ami-4118d72f",
      "pv_ebs"  => "ami-4118d72f"
    },
    "sa-east-1" => {
      "hvm_ebs" => "ami-8631b5ea",
      "hvm_gp2" => "ami-fbfa41e6",
      "pv_ebs"  => "ami-93fb408e"
    }
  })

  Parameter "NatInstanceType" do
    Type "String"
    Description "The instance type for the NAT instances"
    AllowedPattern "^[a-zA-Z][0-9]\.[0-9a-zA-Z]+"
    ConstraintDescription "Must be a valid image type, i.e 't2.micro'"
    Default "t2.micro"
  end

  Parameter "NatVirtualisationType" do
    Type "String"
    Description "The type of virtualisation to use for the NAT instances"
    AllowedValues ["hvm_ebs", "hvm_gp2", "pv_ebs"]
    Default "hvm_ebs"
  end

  %w{one two three}.each do |name|
    Parameter "PrivateSubnetCidr#{name}" do
      Type "AWS::EC2::Subnet::Id"
      Description "The CIDR block for private subnet #{name}"
      AllowedPattern "^[1-9]\\d{0,2}(\\.\\d{1,3}){3}/\\d{1,2}$"
      ConstraintDescription "Must be a CIDR block of the form x.x.x.x/x"
      MaxLength 18
      MinLength 9
    end

    Parameter "PublicSubnetCidr#{name}" do
      Type "AWS::EC2::Subnet::Id"
      Description "The CIDR block for private subnet #{name}"
      AllowedPattern "^[1-9]\\d{0,2}(\\.\\d{1,3}){3}/\\d{1,2}$"
      ConstraintDescription "Must be a CIDR block of the form x.x.x.x/x"
      MaxLength 18
      MinLength 9
    end

    Resource "AllowFromSharedSubnet#{name}ToPrivateSubnetAclEntry" do
      Type "AWS::EC2::NetworkAclEntry"
      Property "CidrBlock", Ref("PrivateSubnetCidr#{name}")
      Property "Egress", false
      Property "NetworkAclId", "1"#Ref("SubnetAcl")
      Property "PortRange", {
        "From" => "-1",
        "To" => "-1"
      }
      Property "Protocol", "-1"
      Property "RuleAction", "allow"
      Property "RuleNumber", rule_number.generate
    end

    Resource "AllowToSharedSubnet#{name}FromPrivateSubnetAclEntry" do
      Type "AWS::EC2::NetworkAclEntry"
      Property "CidrBlock", Ref("PrivateSubnetCidr#{name}")
      Property "Egress", true
      Property "NetworkAclId", "1"#Ref("SubnetAcl")
      Property "PortRange", {
        "From" => "-1",
        "To" => "-1"
      }
      Property "Protocol", "-1"
      Property "RuleAction", "allow"
      Property "RuleNumber", rule_number.generate
    end

    Resource "AllowFromSharedSubnet#{name}ToPublicSubnetAclEntry" do
      Type "AWS::EC2::NetworkAclEntry"
      Property "CidrBlock", Ref("PublicSubnetCidr#{name}")
      Property "Egress", false
      Property "NetworkAclId", "1"#Ref("SubnetAcl")
      Property "PortRange", {
        "From" => "-1",
        "To" => "-1"
      }
      Property "Protocol", "-1"
      Property "RuleAction", "allow"
      Property "RuleNumber", rule_number.generate
    end

    Resource "AllowToSharedSubnet#{name}FromPublicSubnetAclEntry" do
      Type "AWS::EC2::NetworkAclEntry"
      Property "CidrBlock", Ref("PublicSubnetCidr#{name}")
      Property "Egress", true
      Property "NetworkAclId", "1"#Ref("SubnetAcl")
      Property "PortRange", {
        "From" => "-1",
        "To" => "-1"
      }
      Property "Protocol", "-1"
      Property "RuleAction", "allow"
      Property "RuleNumber", rule_number.generate
    end

    Resource "Nat#{name}" do
      Type "AWS::EC2::Instance"

      Property "ImageId", FnFindInMap("NATAMI", Ref("AWS::Region"), Ref("NatVirtualisationType"))
      Property "InstanceType", Ref("NatInstanceType")
      Property "SecurityGroupIds", [
        Ref("VpcNatSecurityGroup")
      ]
      Property "SourceDestCheck", false
      Property "SubnetId", Ref("PublicSubnet#{name}")
      Property "Tags", [
        {
          "Key"   => "Name",
          "Value" => "Nat#{name}"
        }
      ]
    end

    Resource "Nat#{name}EIP" do
      Type "AWS::EC2::EIP"
      Property "Domain", "vpc"
    end

    Resource "Nat#{name}EIPAssociation" do
      Type "AWS::EC2::EIPAssociation"

      Property "AllocationId", FnGetAtt("Nat#{name}EIP", "AllocationId")
      Property "InstanceId", Ref("Nat#{name}")
    end

  end

  Parameter "VpcCidr" do
    Type "AWS::EC2::VPC::Id"
    Description "IP Address range for the VPC."
    ConstraintDescription "Must be a CIDR block of the form x.x.x.x/x"
    AllowedPattern "^[1-9]\\d{0,2}(\\.\\d{1,3}){3}/\\d{1,2}$"
    MaxLength 18
    MinLength 9
  end

  Resource "AllowFromExternalSubnetAclEntry" do
    Type "WS::EC2::NetworkAclEntry"

    Property "CidrBlock", "0.0.0.0/0"
    Property "Egress", false
    Property "NetworkAclId", "1"#Ref("SubnetAcl")
    Property "PortRange", {
      "From" => "-1",
      "To" => "-1"
    }
    Property "Protocol", "-1"
    Property "RuleAction", "Allow"
    Property "RuleNumber", 500
  end

  Resource "InternetGateway" do
    Type "AWS::EC2::InternetGateway"

    Property "Tags", [
      {
        "Key"   => "Stack",
        "Value" => Ref("AWS::StackName")
      },
      {
        "Key"   => "NetworkType",
        "Value" => "Public"
      }
    ]
  end

  Resource "InternetGatewayVpcAttachment" do
    Type "AWS::EC2::VPCGatewayAttachment"

    Property "InternetGatewayId", Ref("InternetGateway")
    Property "VpcId", Ref("VPC")
  end
end
