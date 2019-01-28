#!/bin/bash

while getopts "p:u:r:" OPT; do
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

if [ -z ${CALLBACK_URLS} ]; then
    echo "Missing -u parameter."
    echo "Usage: $0 -p <aws profile> -p <aws region> -u <comma-separated list of aouthentication callback urls>"
    exit 1
fi
if [ -z ${AWS_PROFILE} ]; then
    echo "Missing -p parameter."
    echo "Usage: $0 -p <aws profile> -p <aws region> -u <comma-separated list of aouthentication callback urls>"
    exit 1
fi
if [ -z ${AWS_REGION} ]; then
    echo "Missing -r parameter."
    echo "Usage: $0 -p <aws profile> -p <aws region> -u <comma-separated list of aouthentication callback urls>"
    exit 1
fi

AWS_ACCOUNTID=$(aws sts get-caller-identity --query Account --output text)

ARTIFACT_BUCKET="cf-il-auth-at-edge.${AWS_REGION}.${AWS_ACCOUNTID}"
ARTIFACT_BUCKET_US="cf-il-auth-at-edge.us-east-1.${AWS_ACCOUNTID}"
WEBSITE_BUCKET="web-il-auth-at-edge.${AWS_REGION}.${AWS_ACCOUNTID}"
ITEM_KEY_PREFIX="il-auth-at-edge"

echo "Check s3 buckets and create when necessary"
if ! aws s3 ls | grep -q "${ARTIFACT_BUCKET}"; then
    aws cloudformation deploy \
        --region ${AWS_REGION} \
        --stack-name il-auth-at-edge-artifact-bucket-${AWS_REGION} \
        --template-file cloudformation/s3-artifact-bucket.yaml \
        --no-fail-on-empty-changeset || exit 1
fi
if ! aws s3 ls | grep -q "${ARTIFACT_BUCKET_US}"; then
    aws cloudformation deploy \
        --region us-east-1 \
        --stack-name il-auth-at-edge-artifact-bucket-us-east-1 \
        --template-file cloudformation/s3-artifact-bucket.yaml \
        --no-fail-on-empty-changeset || exit 1
fi
if ! aws s3 ls | grep -q "${WEBSITE_BUCKET}"; then
    aws cloudformation deploy \
        --region ${AWS_REGION} \
        --stack-name il-auth-at-edge-website-s3-bucket-${AWS_REGION} \
        --template-file cloudformation/s3-website-bucket.yaml \
        --no-fail-on-empty-changeset || exit 1
fi

rm -rf /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/
mkdir -p /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/
rm -rf /tmp/${ARTIFACT_BUCKET_US}/${ITEM_KEY_PREFIX}/
mkdir -p /tmp/${ARTIFACT_BUCKET_US}/${ITEM_KEY_PREFIX}/
echo "Create zipfile containing edge lambda stuff"
(cd lambda/lambda-edge-function; zip -r /tmp/${ARTIFACT_BUCKET_US}/${ITEM_KEY_PREFIX}/edge-auth.zip ./*)
echo "Create zipfile containing userpool lambda stuff"
(cd lambda/userpool-function; pip3 install cfnresponse --system --target .; zip -r /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/userpool.zip ./*)
echo "Create zipfile containing lambda creation lambda stuff"
(cd lambda/create-lambda-function; pip3 install cfnresponse --system --target .; zip -r /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/createlambda.zip ./*)
echo "Copy subtemplates to /tmp"
cp cloudformation/cognito-user-pool.yaml /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/
cp cloudformation/lambda-at-edge.yaml /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/
echo "Sync artifacts to s3"
aws --region ${AWS_REGION} s3 sync /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/ s3://${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/ --delete
aws --region us-east-1 s3 sync /tmp/${ARTIFACT_BUCKET_US}/${ITEM_KEY_PREFIX}/ s3://${ARTIFACT_BUCKET_US}/${ITEM_KEY_PREFIX}/ --delete
echo "Sync website to s3"
aws --region ${AWS_REGION} s3 sync ./website s3://${WEBSITE_BUCKET}/${ITEM_KEY_PREFIX}/ --delete
echo "Deploy cloudformation stack"
aws cloudformation deploy \
    --region ${AWS_REGION} \
    --stack-name il-auth-at-edge \
    --template-file cloudformation/edge-auth.yaml \
    --parameter-overrides "ArtifactBucketUs=${ARTIFACT_BUCKET_US}" "ArtifactBucket=${ARTIFACT_BUCKET}" "ArtifactPrefix=${ITEM_KEY_PREFIX}" "CallbackUrls=${CALLBACK_URLS}" \
    --capabilities CAPABILITY_IAM