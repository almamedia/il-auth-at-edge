#!/bin/bash

export AWS_REGION="us-east-1"

while getopts "p:u:" OPT; do
    case ${OPT} in
        p)
            export AWS_PROFILE=${OPTARG}
            ;;
        u)
            export CALLBACK_URLS=${OPTARG}
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

if [ -z ${CALLBACK_URLS} -o -z ${AWS_PROFILE} ]; then
    echo "Missing parameters."
    echo "Usage: $0 -p <aws profile> -u <comma-separated list of aouthentication callback urls>"
fi

AWS_ACCOUNTID=$(aws sts get-caller-identity --query Account --output text)

ARTIFACT_BUCKET="cf-il-auth-at-edge.${AWS_REGION}.${AWS_ACCOUNTID}"
WEBSITE_BUCKET="web-il-auth-at-edge.${AWS_REGION}.${AWS_ACCOUNTID}"
ITEM_KEY_PREFIX="il-auth-at-edge"

echo "Check s3 buckets and create when necessary"
if ! aws s3 ls | grep -q "${ARTIFACT_BUCKET}\|${WEBSITE_BUCKET}"; then
    aws cloudformation deploy \
        --region ${AWS_REGION} \
        --stack-name il-auth-at-edge-s3-buckets \
        --template-file cloudformation/s3-buckets.yaml \
        --no-fail-on-empty-changeset || exit 1
fi

echo "Create zipfile containing lambda stuff"
rm -rf /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/
mkdir -p /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/
(cd node/lambda-edge-function; zip -r /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/edge-auth.zip ./*)
echo "Copy subtemplates to /tmp"
cp cloudformation/cognito-user-pool.yaml /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/
cp cloudformation/lambda-at-edge.yaml /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/
echo "Sync artifacts to s3"
aws --region ${AWS_REGION} s3 sync /tmp/${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/ s3://${ARTIFACT_BUCKET}/${ITEM_KEY_PREFIX}/ --delete
echo "Sync website to s3"
aws --region ${AWS_REGION} s3 sync ./website s3://${WEBSITE_BUCKET}/${ITEM_KEY_PREFIX}/ --delete
echo "Deploy cloudformation stack"
aws cloudformation deploy \
    --region ${AWS_REGION} \
    --stack-name il-auth-at-edge \
    --template-file cloudformation/edge-auth.yaml \
    --parameter-overrides "ArtifactBucket=${ARTIFACT_BUCKET}" "ArtifactPrefix=${ITEM_KEY_PREFIX}" "CallbackUrls=${CALLBACK_URLS}" \
    --capabilities CAPABILITY_IAM