#!/bin/bash
# Script to set the password on the attendee IAM Users and dump them to a CSV File

# Retrieve attendee_user_name from cdk.json
ATTENDEE_USER_NAME=( $(jq -r .context.attendee_user_name cdk.json) )

# Get the ARNs of the attendee users and put them into an array
USER_NAMES=( $(aws iam list-users --query "Users[][UserName]" --output text | grep $ATTENDEE_USER_NAME) )
#echo ${USER_NAMES[*]}

# Get the length of that array (i.e. # of users) as NUM_USERS
NUM_USERS=${#USER_NAMES[*]}
#echo $NUM_USERS

# Create a new USER_PASSWORDS array full of random passwords for our users
for (( c=1; c<=$NUM_USERS; c++ ))
do
    USER_PASSWORDS+=( $(./pwgen.py) )
done
#echo ${USER_PASSWORDS[*]}

# Dump out our CSV
echo "username,password" > workshop_passwords.csv
for (( c=1; c<=$NUM_USERS; c++ ))
do
    echo "${USER_NAMES[$c-1]},${USER_PASSWORDS[$c-1]}" >> workshop-passwords.csv
done

# Create our login profiles using the AWS CLI
for (( c=1; c<=$NUM_USERS; c++ ))
do
    aws iam create-login-profile --user-name ${USER_NAMES[$c-1]} --password ${USER_PASSWORDS[$c-1]}
done
