#!/bin/bash

export AWS_REGION="us-east-1"

while getopts "p:" OPT; do
    case ${OPT} in
        p)
            export AWS_PROFILE=${OPTARG}
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

AWS_ACCOUNTID=$(aws sts get-caller-identity --query Account --output text)

ARTIFACT_BUCKET="cf-il-auth-at-edge.${AWS_REGION}.${AWS_ACCOUNTID}"
ARTIFACT_PREFIX="il-auth-at-edge"

echo "Check artifact bucket and create when necessary"
if ! aws s3 ls | grep -q "${ARTIFACT_BUCKET}"; then
    aws cloudformation deploy \
        --region ${AWS_REGION} \
        --stack-name cloudformation-artifact-bucket \
        --template-file templates/artifact-bucket.yaml
fi

echo "Create zipfile containing lambda stuff"
rm -rf /tmp/${ARTIFACT_BUCKET}/${ARTIFACT_PREFIX}/
mkdir -p /tmp/${ARTIFACT_BUCKET}/${ARTIFACT_PREFIX}/
(cd node/lambda-edge-function; zip -r /tmp/${ARTIFACT_BUCKET}/${ARTIFACT_PREFIX}/edge-auth.zip ./*)
echo "Copy subtemplates to /tmp"
cp templates/cognito-user-pool.yaml /tmp/${ARTIFACT_BUCKET}/${ARTIFACT_PREFIX}/
cp templates/lambda-at-edge.yaml /tmp/${ARTIFACT_BUCKET}/${ARTIFACT_PREFIX}/
echo "Sync artifacts to s3"
aws --region ${AWS_REGION} s3 sync /tmp/${ARTIFACT_BUCKET}/${ARTIFACT_PREFIX}/ s3://${ARTIFACT_BUCKET}/${ARTIFACT_PREFIX}/ --delete
echo "Deploy cloudformation stack"
aws cloudformation deploy \
    --region ${AWS_REGION} \
    --stack-name il-auth-at-edge \
    --template-file templates/edge-auth.yaml \
    --parameter-overrides "ArtifactBucket=${ARTIFACT_BUCKET}" "ArtifactPrefix=${ARTIFACT_PREFIX}" \
    --capabilities CAPABILITY_IAM