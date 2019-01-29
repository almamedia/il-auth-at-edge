import boto3
import cfnresponse
import base64
def handler(event, context):
    responseData = {}
    cognitoIDPClient = boto3.client('cognito-idp')
    print (str(event)) 
    PoolName ='il-auth-at-edge-userpool'
    ClientName='il-auth-at-edge-userpool-client'
    UserPoolId = ''
    ClientId = ''
    Domain = ''
    try: 
        try:
            print("Try PhysicalResourceId")
            ResourceIdString = base64.b64decode(event['PhysicalResourceId']).decode()
            UserPoolId = ResourceIdString.split(':')[0]
            ClientId = ResourceIdString.split(':')[1]
            Domain = ResourceIdString.split(':')[2]
            print("Decoded values from PhysicalResourceId: {" + UserPoolId + ", " + ClientId + ", " + Domain + "}")        
        except:
            # Try to find user pool and client that were created previously and 
            # not coded to resourceid. This is needed when updating stack that was 
            # created from earlier version of this project since userpools and clients 
            # were not properly tracked
            print("PhysicalResourceId dd not contain resource ids, try API")
            pools = cognitoIDPClient.list_user_pools(MaxResults=60)
            for pool in pools['UserPools']:
                if pool['Name'] == PoolName:
                    UserPoolId = pool['Id']
                    break
            if UserPoolId :
                clients = cognitoIDPClient.list_user_pool_clients(UserPoolId=UserPoolId, MaxResults=60)
                for userpoolclient in clients['UserPoolClients']:
                    if userpoolclient['ClientName'] == ClientName:
                        ClientId = userpoolclient['ClientId']
                        break
                pool = cognitoIDPClient.describe_user_pool(UserPoolId=UserPoolId)['UserPool']
                Domain = pool['Domain']
            print("Values from API: {" + UserPoolId + ", " + ClientId + ", " + Domain + "}")        
        if UserPoolId and ClientId and Domain and event['RequestType'] == 'Create':
            print("We have existing userpool with client and domain, do Update instead of" + event['RequestType'])
            event['RequestType'] = 'Update'
            customResourcePhysicalId = base64.b64encode((UserPoolId + ':' + ClientId + ':' + Domain).encode()).decode()
            event['PhysicalResourceId'] = customResourcePhysicalId

        if event['RequestType'] == 'Create':
            print("Create")
            response = cognitoIDPClient.create_user_pool(
                AdminCreateUserConfig={
                    'AllowAdminCreateUserOnly': True,
                    'UnusedAccountValidityDays': 7
                },
                PoolName=PoolName,
                AutoVerifiedAttributes=['email'],
                Schema=[
                    {
                        'Name': 'email',
                        'Required': True
                    }
                ]
            )
            CreatedUserPoolId = response['UserPool']['Id']
            response = cognitoIDPClient.create_user_pool_client(
                UserPoolId=CreatedUserPoolId,
                ClientName=ClientName,
                ReadAttributes=[
                    'address', 'birthdate', 'email', 'email_verified', 'family_name', 'gender', 'given_name', 'locale', 'middle_name', 'name', 'nickname', 'phone_number', 'phone_number_verified', 'picture', 'preferred_username', 'profile', 'updated_at', 'website', 'zoneinfo'
                ],
                WriteAttributes=[
                    'address', 'birthdate', 'email', 'family_name', 'gender', 'given_name', 'locale', 'middle_name', 'name', 'nickname', 'phone_number', 'picture', 'preferred_username', 'profile', 'updated_at', 'website', 'zoneinfo'
                ],
                SupportedIdentityProviders=['COGNITO'],
                CallbackURLs=event['ResourceProperties']['CallbackUrls'].split(','),
                LogoutURLs=event['ResourceProperties']['CallbackUrls'].split(','),
                AllowedOAuthFlows=['implicit','code'],
                AllowedOAuthScopes=['aws.cognito.signin.user.admin','openid'],
                AllowedOAuthFlowsUserPoolClient=True
            )
            CreatedClientId = response['UserPoolClient']['ClientId']
            response = cognitoIDPClient.create_user_pool_domain(
                Domain=str(CreatedClientId),
                UserPoolId=CreatedUserPoolId
            )
            CreatedDomain=CreatedClientId
            responseData['UserPoolId'] = CreatedUserPoolId
            responseData['ClientId'] = CreatedClientId
            customResourcePhysicalId = base64.b64encode((CreatedUserPoolId + ':' + CreatedClientId + ':' + CreatedDomain).encode()).decode()
            print("Create SUCCESS, ResponseData=" + str(responseData))
            cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData, customResourcePhysicalId)
        elif event['RequestType'] == 'Update':
            print("Update")
            cognitoIDPClient.update_user_pool_client(
                UserPoolId=UserPoolId,
                ClientId=ClientId,
                ClientName=ClientName,
                ReadAttributes=[
                    'address', 'birthdate', 'email', 'email_verified', 'family_name', 'gender', 'given_name', 'locale', 'middle_name', 'name', 'nickname', 'phone_number', 'phone_number_verified', 'picture', 'preferred_username', 'profile', 'updated_at', 'website', 'zoneinfo'
                ],
                WriteAttributes=[
                    'address', 'birthdate', 'email', 'family_name', 'gender', 'given_name', 'locale', 'middle_name', 'name', 'nickname', 'phone_number', 'picture', 'preferred_username', 'profile', 'updated_at', 'website', 'zoneinfo'
                ],
                SupportedIdentityProviders=['COGNITO'],
                CallbackURLs=event['ResourceProperties']['CallbackUrls'].split(','),
                LogoutURLs=event['ResourceProperties']['CallbackUrls'].split(','),
                AllowedOAuthFlows=['implicit','code'],
                AllowedOAuthScopes=['aws.cognito.signin.user.admin','openid'],
                AllowedOAuthFlowsUserPoolClient=True
            )
            print("Update SUCCESS - responseData=" + str(responseData))
            cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData, event['PhysicalResourceId'])
        elif event['RequestType'] == 'Delete':
            print("Delete")
            cognitoIDPClient.delete_user_pool_domain(Domain=Domain, UserPoolId=UserPoolId)
            cognitoIDPClient.delete_user_pool_client(UserPoolId=UserPoolId, ClientId=ClientId)
            cognitoIDPClient.delete_user_pool(UserPoolId=UserPoolId)
            print("Delete SUCCESS - responseData=" + str(responseData))
            cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData, event['PhysicalResourceId'])
    except Exception as e:
        responseData['Error'] = str(e)
        print("FAILED, Exception: " + responseData['Error'])
        cfnresponse.send(event, context, cfnresponse.FAILED, responseData, event['PhysicalResourceId'] if 'PhysicalResourceId' in event.keys() else '') 
