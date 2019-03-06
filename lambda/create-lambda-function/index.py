import cfnresponse
import os
import boto3
import base64
def handler(event, context):
    responseData = {}
    S3Bucket = event['ResourceProperties']['Code']['S3Bucket']
    S3Key = event['ResourceProperties']['Code']['S3Key']
    FunctionName = event['ResourceProperties']['FunctionName']
    Runtime = event['ResourceProperties']['Runtime']
    Timeout = int(event['ResourceProperties']['Timeout'])
    MemorySize = int(event['ResourceProperties']['MemorySize'])
    Handler = event['ResourceProperties']['Handler']
    Role = event['ResourceProperties']['Role']
    AWSRegion = event['ResourceProperties']['AWSRegion']
    lambdaClient = boto3.client('lambda', region_name=AWSRegion)
    try: 
        if event['RequestType'] == 'Create' :
            response = lambdaClient.create_function(
                Publish=True,
                FunctionName=FunctionName,
                Code={
                'S3Bucket':S3Bucket,
                'S3Key':S3Key
                },
                Timeout=Timeout,
                MemorySize=MemorySize,
                Runtime=Runtime,
                Role=Role,
                Handler=Handler,
            )
            responseData['Arn']=response['FunctionArn']
            responseData['Version']=response['Version']
            print("SUCCESS, ResponseData=" + str(responseData))
            cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData, response['FunctionArn'])
        elif event['RequestType'] == 'Update' :
            response = lambdaClient.update_function_configuration(
                FunctionName=event['PhysicalResourceId'],
                Timeout=Timeout,
                MemorySize=MemorySize,
                Runtime=Runtime,
                Role=Role,
                Handler=Handler
            )
            response = lambdaClient.update_function_code(
                Publish=True,
                FunctionName=event['PhysicalResourceId'],
                S3Bucket=S3Bucket,
                S3Key=S3Key
            )
            responseData['Arn']=event['PhysicalResourceId']
            responseData['Version']=response['Version']
            print("Update SUCCESS, ResponseData=" + str(responseData))
            cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData, event['PhysicalResourceId'])
        elif event['RequestType'] == 'Delete' :
            lambdaClient.delete_function(FunctionName=event['PhysicalResourceId'])
            print("Delete SUCCESS")
            cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData, event['PhysicalResourceId'] if 'PhysicalResourceId' in event.keys() else '')
    except Exception as e:
        responseData['Error'] = str(e)
        cfnresponse.send(event, context, cfnresponse.FAILED, responseData, event['PhysicalResourceId']) 
        print("FAILED ERROR: " + responseData['Error'])
