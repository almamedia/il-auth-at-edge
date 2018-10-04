# Authorization Lambda At Edge

Authorization with Lambda@Edge and JSON Web Tokens (JWTs). Modified from example here: https://github.com/aws-samples/authorization-lambda-at-edge/

## Sign-in flow

1. Viewer requests URL from Cloudfront
2. Edge Lambda function checks for Authorization header or IlAuthAtEdge cookie.
3. Edge Lambda verifies the value from header/cookie. It should be JWT token issued from il-auth-at-edge Cognito userpool.
4. If token is valid, Edge Lambda passes the request to Cloudfront which returns the requested content from edge cache or origin to Viewer
5. If token is not valid, Edge Lambda will return 302 Redirect response to Viewer's browser and Viewer is taken to Cognito's login page.
6. After successful login, Cognito redirects viewer's browser to https://<hostname from original request>/il-auth-at-edge/signin/index.html#<Cognito's id_token and access_token plus bunch of variables>*) This page reads Cognito's access token and sets it to IlAuthAtEdge cookie.
7. Viewer is redirected to https://<hostname from original request>/ and this time Cloudfront&Lambda should let request through

*) NOTE: Cognito's tokens are returned in fragment part of the signin redirect URL, not in query string, cookie  or headers. Therefore the page where user is redirected must read them in browser and store them in cookies. il-aut-at-edge offers a very basic signin redirect page that does precisely this. You can make your own handler fro signin redirects. ATM it must be in /il-auth-at-edge/signin/index.html path under the same hostname the pages requiring login.

## Installation

Istallation creates set of nested Cloudformation stacks in us-east-1 (N. Vriginia) region on account specified by --profile parameter.

You should have aws cli installed and profiles set up in your ~/.aws/credentials file.

Artifacts (lambda auth function and cloudfromation templates and signin redirect page) are stored in s3 buckets. Buckets are created if they don't exist.

Run
```
./deploy.sh -p <your aws credentials profile> -u <comma separated list of allowed signin redirect urls>
```

-u parameter should have at least one signin redirect url, ATM they look like this: https://<CNAME pointing to cloudfront distribution OR cloudfront distribution domain name if there's no CNAME>/il-auth-at-edge/signin/index.html

When the cloudformation has finished, see the outputs of the main il-auth-at-eddge stack. There's link to Lambda Function in AWS console. Go there and in Actions Dropdown select Publish New Version. Note the ARN of the version, this is needed later on.

### Manual Cloudfront setup

Add web-il-auth-at-edge.us-east-1.<your AWS accountId> as a new origin to your Cloudfront distribution. 

  - Check Restrict Bucket Access and select Origin Access Identity. Check Update Bucket Policy or set it up manually to allow access for the selected OAI

Add cache behavior for the new origin with path pattern /il-auth-at-edge/*

  - DON'T set any Lambda Function Associations to this behaviour!

Add the Edge Lambda function association to all relevant other cache behaviors in your Cloudfront distribution

  - Cloudfront Event: Viewer Request
  - Lambda function ARN: ARN for the version of Edge Lambda you published earlier

## License

This library is licensed under the Apache 2.0 License. 
