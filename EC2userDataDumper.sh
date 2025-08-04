#!/bin/bash

cat << "EOF"
 _____ _                 _______                     _       _       
/  __ \ |               | | ___ \                   | |     (_)      
| /  \/ | ___  _   _  __| | |_/ /_ __ ___  __ _  ___| |__    _  ___  
| |   | |/ _ \| | | |/ _` | ___ \ '__/ _ \/ _` |/ __| '_ \  | |/ _ \ 
| \__/\ | (_) | |_| | (_| | |_/ / | |  __/ (_| | (__| | | |_| | (_) |
 \____/_|\___/ \__,_|\__,_\____/|_|  \___|\__,_|\___|_| |_(_)_|\___/ 


AWS Script that retrieves and base64 decodes userData from EC2 instances across all regions with optional profile.

EOF

AWS_PROFILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      AWS_PROFILE="$2"
      shift 2
      ;;
    *)
      echo "[ERROR] Unknown argument: $1"
      echo "Usage: $0 [--profile <aws-profile-name>]"
      exit 1
      ;;
  esac
done

if [[ -n "$AWS_PROFILE" ]]; then
  PROFILE_OPT="--profile $AWS_PROFILE"
  echo "[+] Using AWS profile: $AWS_PROFILE"
else
  PROFILE_OPT=""
  echo "[+] Using default AWS credentials"
fi

regions=(
  "us-east-1" "us-east-2" "us-west-1" "us-west-2"
  "af-south-1" "ap-east-1" "ap-south-1" "ap-south-2"
  "ap-southeast-1" "ap-southeast-2" "ap-southeast-3" "ap-southeast-4"
  "ap-northeast-1" "ap-northeast-2" "ap-northeast-3"
  "ca-central-1"
  "eu-central-1" "eu-central-2"
  "eu-west-1" "eu-west-2" "eu-west-3"
  "eu-north-1"
  "eu-south-1" "eu-south-2"
  "il-central-1"
  "me-south-1" "me-central-1"
  "sa-east-1"
)

for region in "${regions[@]}"; do
  echo ""
  echo "=============================="
  echo "🔍 Region: $region"
  echo "=============================="

  instance_ids=$(aws ec2 describe-instances --region "$region" $PROFILE_OPT \
    --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null)

  if [[ -z "$instance_ids" ]]; then
    echo "No instances found or access denied in region $region"
    continue
  fi

  for instance_id in $instance_ids; do
    echo ""
    echo "➡️  Getting userData for instance: $instance_id"

    user_data=$(aws ec2 describe-instance-attribute --region "$region" $PROFILE_OPT \
      --instance-id "$instance_id" --attribute userData --output text 2>/dev/null)

    if [ -n "$user_data" ]; then
      encoded=$(echo "$user_data" | sed 's/^USERDATA\s*//' | sed '1d' | sed 's/^[[:space:]]*//')

      echo "📦 Base64-encoded userData:"
      echo "$encoded"
      echo ""
      echo "🔓 Decoded userData:"
      echo "------------------------------"
      echo "$encoded" | base64 -d 2>/dev/null || echo "[!] Failed to decode userData"
      echo "------------------------------"
    else
      echo "⚠️  No userData found for instance $instance_id"
    fi
  done
done

