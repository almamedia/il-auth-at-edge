'use strict';
var jwt = require('jsonwebtoken');  
var jwkToPem = require('jwk-to-pem');

/*
TO DO:
copy values from CloudFormation outputs into USERPOOLID and JWKS variables
*/

var USERPOOLID = '##USERPOOLID##';
var CLIENTID = '##CLIENTID##';
var JWKS = '##JWKS##';
var REGION = '##REGION##';

/*
verify values above
*/

var iss = 'https://cognito-idp.' + REGION + '.amazonaws.com/' + USERPOOLID;
var pems;

pems = {};
var keys = JSON.parse(JWKS).keys;
for(var i = 0; i < keys.length; i++) {
    //Convert each key to PEM
    var key_id = keys[i].kid;
    var modulus = keys[i].n;
    var exponent = keys[i].e;
    var key_type = keys[i].kty;
    var jwk = { kty: key_type, n: modulus, e: exponent};
    var pem = jwkToPem(jwk);
    pems[key_id] = pem;
}

function parseCookieHeader(cookie) {
    var parsedCookie = {}
    cookie.split(";").map(function(field) {
        var arr = field.split("=")
        var result = {}
        if(arr.length == 1) {
            result.key = arr[0].trim()
        } else if(arr.length > 1) {
            result.key = arr[0].trim()
            result.value = arr[1].trim()
        }
        return result;
    }).map(function(item){
        parsedCookie[item.key] = item.value ? item.value : true;
    });
    return parsedCookie;
}

exports.handler = (event, context, callback) => {
    const cfrequest = event.Records[0].cf.request;
    const headers = cfrequest.headers;
    const cookieHeaders = headers.cookie;

    const response401 = {
        status: '401',
        statusDescription: 'Unauthorized',
        headers: {
            'cache-control': [
                {
                    key: 'Cache-Control',
                    value: 'no-store' 
                }
            ]
        }
    };

    const response302 = {
        status: '302',
        headers: {
            'location': [
                {
                    key: 'Location',
                    value: 'https://' + CLIENTID + '.auth.' + REGION + '.amazoncognito.com/login?' + 'client_id=' + CLIENTID + '&response_type=token' + '&redirect_uri=https://' + headers.host[0].value + '/il-auth-at-edge/signin/index.html'
                }
            ],
            'cache-control': [
                {
                    key: 'Cache-Control',
                    value: 'no-store' 
                }
            ]
        }
    }

    console.log('getting started');
    console.log('USERPOOLID=' + USERPOOLID);
    console.log('CLIENTID=' + CLIENTID);
    console.log('REGION=' + REGION);
    console.log('pems=' + pems);

    var jwtToken = null;
    
    //Fail if no authorization header or cookie found
    if(!headers.authorization) {
        console.log('no auth header, try cookie');
        if (!cookieHeaders) {
            console.log('no cookies')
            callback(null, response302);
            return false;
        } else {
            for (i = 0; i < cookieHeaders.length; i++) {
                var parsedCookies = parseCookieHeader(cookieHeaders[i].value);
                if (parsedCookies["IlAuthAtEdge"]) {
                    jwtToken = parsedCookies["IlAuthAtEdge"]
                    break;
                }
            }
        }
    } else {
        //strip out 'Bearer ' to extract JWT token only
        var jwtToken = headers.authorization[0].value.slice(7);
    }

    if(!jwtToken) {
        console.log('No JWT Token found');
        callback(null, response302);
        return false;
    }

    console.log('jwtToken=' + jwtToken);

    //Fail if the token is not jwt
    var decodedJwt = jwt.decode(jwtToken, {complete: true});
    if (!decodedJwt) {
        console.log('Not a valid JWT token');
        callback(null, response302);
        return false;
    }

    //Fail if token is not from your UserPool
    if (decodedJwt.payload.iss != iss) {
        console.log('invalid issuer');
        callback(null, response401);
        return false;
    }

    //Reject the jwt if it's not an 'Access Token'
    if (decodedJwt.payload.token_use != 'access') {
        console.log('Not an access token');
        callback(null, response401);
        return false;
    }

    //Get the kid from the token and retrieve corresponding PEM
    var kid = decodedJwt.header.kid;
    var pem = pems[kid];
    if (!pem) {
        console.log('Invalid access token');
        callback(null, response401);
        return false;
    }

    //Verify the signature of the JWT token to ensure it's really coming from your User Pool
    jwt.verify(jwtToken, pem, { issuer: iss }, function(err, payload) {
      if(err) {
        console.log('Token failed verification');
        callback(null, response401);
        return false;
      } else {
        //Valid token. 
        console.log('Successful verification');
        //remove authorization header
        delete cfrequest.headers.authorization;
        //CloudFront can proceed to fetch the content from origin
        callback(null, cfrequest);
        return true;
      }
    });
};




