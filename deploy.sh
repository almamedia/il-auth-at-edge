#!/bin/bash

USAGE="Usage: $0 -p <aws profile> -r <aws region> -u <comma-separated list of aouthentication callback urls>"
while getopts "p:u:r:h" OPT; do
    case ${OPT} in
        p)
            export AWS_PROFILE=${OPTARG}
            ;;
        u)
            export CALLBACK_URLS=${OPTARG}
            ;;
        r)
            export AWS_REGION=${OPTARG}
            ;;
        r)
            echo ${USAGE}
            exit 0
            ;;
        \?)
            echo "invalid option -${OPTARG}"
            exit 1
            ;;
        :)
            echo "option -${OPTARG} requires an argument"
            exit 1
            ;;
    esac
done

: ${CALLBACK_URLS:?"Missing -u parameter. ${USAGE}"}
: ${AWS_PROFILE:?"Missing -u parameter. ${USAGE}"}
: ${AWS_REGION:?"Missing -u parameter. ${USAGE}"}

AWS_ACCOUNTID=$(aws sts get-caller-identity --query Account --output text)

ARTIFACT_BUCKET="cf-il-auth-at-edge.${AWS_REGION}.${AWS_ACCOUNTID}"
ARTIFACT_BUCKET_US="cf-il-auth-at-edge.us-east-1.${AWS_ACCOUNTID}"
WEBSITE_BUCKET="web-il-auth-at-edge.${AWS_REGION}.${AWS_ACCOUNTID}"
ITEM_KEY_PREFIX="il-auth-at-edge"
LAMBDA_ZIP_REVISION_SUFFIX=$(date +%Y%m%d%H%M)

aws cloudformation deploy \
    --region ${AWS_REGION} \
    --stack-name il-auth-at-edge-artifact-bucket-${AWS_REGION} \
    --template-file cloudformation/s3-artifact-bucket.yaml \
    --no-fail-on-empty-changeset || exit 1
aws cloudformation deploy \
    --region us-east-1 \
    --stack-name il-auth-at-edge-artifact-bucket-us-east-1 \
    --template-file cloudformation/s3-artifact-bucket.yaml \
    --no-fail-on-empty-changeset || exit 1
aws cloudformation deploy \
    --region ${AWS_REGION} \
    --stack-name il-auth-at-edge-website-s3-bucket-${AWS_REGION} \
    --template-file cloudformation/s3-website-bucket.yaml \
    --no-fail-on-empty-changeset || exit 1

rm -rf /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/
mkdir -p /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/
rm -rf /tmp/${ARTIFACT_BUCKET_US}/${ITEM_KEY_PREFIX}/
mkdir -p /tmp/${ARTIFACT_BUCKET_US}/${ITEM_KEY_PREFIX}/
rm -rf /tmp/il-auth-at-edge
mkdir -p /tmp/il-auth-at-edge
cp -r lambda /tmp/il-auth-at-edge/
echo "Create zipfile containing edge lambda stuff"
(cd /tmp/il-auth-at-edge/lambda/lambda-edge-function; zip -r /tmp/${ARTIFACT_BUCKET_US}/${ITEM_KEY_PREFIX}/edge-auth-${LAMBDA_ZIP_REVISION_SUFFIX}.zip ./*)
echo "Create zipfile containing userpool lambda stuff"
(cd /tmp/il-auth-at-edge/lambda/userpool-function; pip3 install cfnresponse --system --target .; zip -r /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/userpool-${LAMBDA_ZIP_REVISION_SUFFIX}.zip ./*)
echo "Create zipfile containing lambda creation lambda stuff"
(cd /tmp/il-auth-at-edge/lambda/create-lambda-function; pip3 install cfnresponse --system --target .; zip -r /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/createlambda-${LAMBDA_ZIP_REVISION_SUFFIX}.zip ./*)
echo "Create zipfile containing config update lambda stuff"
(cd /tmp/il-auth-at-edge/lambda/update-config-function; pip3 install cfnresponse --system --target .; zip -r /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/updateconfig-${LAMBDA_ZIP_REVISION_SUFFIX}.zip ./*)
echo "Copy subtemplates to /tmp"
cp cloudformation/cognito-user-pool.yaml /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/
cp cloudformation/lambda-at-edge.yaml /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/
echo "Sync artifacts to s3"
aws --region ${AWS_REGION} s3 sync /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/ s3://${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/
aws --region us-east-1 s3 sync /tmp/${ARTIFACT_BUCKET_US}/${ITEM_KEY_PREFIX}/ s3://${ARTIFACT_BUCKET_US}/${ITEM_KEY_PREFIX}/
aws --region ${AWS_REGION} s3 sync ./website s3://${WEBSITE_BUCKET}/${ITEM_KEY_PREFIX}/
echo "Deploy cloudformation stack"
aws cloudformation deploy \
    --region ${AWS_REGION} \
    --stack-name il-auth-at-edge \
    --template-file cloudformation/edge-auth.yaml \
    --parameter-overrides "ArtifactBucketUs=${ARTIFACT_BUCKET_US}" "ArtifactBucket=${ARTIFACT_BUCKET}" "ArtifactPrefix=${ITEM_KEY_PREFIX}" "CallbackUrls=${CALLBACK_URLS}" "LambdaZipRevisionSuffix=${LAMBDA_ZIP_REVISION_SUFFIX}" \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset