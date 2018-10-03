## Authorization Lambda At Edge

Authorization with Lambda@Edge and JSON Web Tokens (JWTs). Modified from example here: https://github.com/aws-samples/authorization-lambda-at-edge/

### Installation

Istallation creates set of nested Cloudformation stacks in us-east-1 (N. Vriginia) region on account specified by --profile parameter.

You should have aws cli installed and profiles set up in your ~/.aws/credentials file.

Artifacts (lambda auth function and cloudfromation templates) are stored in cloudformation.<AWS region>.<AWS accountId> bucket under il-auth-at-edge prefix. The bucket is created if it does not exist.

Run
```
./deploy.sh -p <your aws credentials profile>
```


## License

This library is licensed under the Apache 2.0 License. 
