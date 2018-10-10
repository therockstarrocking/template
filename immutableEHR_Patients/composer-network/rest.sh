#!/bin/bash
export COMPOSER_PROVIDERS='{
    "google": {
        "provider": "google",
        "module": "passport-google-oauth2",
        "clientID": "601598569509-85b7bkl6hsocgnbhg5ueko6opecsrlmp.apps.googleusercontent.com",
        "clientSecret": "PV_34WL9sNdplkECOqcP_dDf",
        "authPath": "/auth/google",
        "callbackURL": "/auth/google/callback",
        "scope": "https://www.googleapis.com/auth/plus.login",
        "successRedirect": "http://192.168.1.158:3001/explorer",
        "failureRedirect": "/"
    }
}'

echo $COMPOSER_PROVIDERS
composer-rest-server -p 9090 -w true -n never -c alice@immutableehr
