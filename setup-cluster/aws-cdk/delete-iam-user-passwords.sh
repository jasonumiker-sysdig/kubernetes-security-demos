#!/bin/bash
# Script to delete the login profiles so that the Attendee stacks delete cleanly

# Retrieve attendee_user_name from cdk.json
ATTENDEE_USER_NAME=( $(jq -r .context.attendee_user_name cdk.json) )

# Get the usernames of the attendee users and put them into an array
USER_NAMES=( $(aws iam list-users --query "Users[][UserName]" --output text | grep $ATTENDEE_USER_NAME) )
#echo ${USER_NAMES[*]}

# Get the length of that array (i.e. # of users) as NUM_USERS
NUM_USERS=${#USER_NAMES[*]}
#echo $NUM_USERS

# Delete the login profiles for each attendee user using the AWS CLI
for (( c=1; c<=$NUM_USERS; c++ ))
do
    aws iam delete-login-profile --user-name ${USER_NAMES[$c-1]} || true
done
