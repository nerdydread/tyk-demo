#!/bin/bash

source scripts/common.sh
deployment="Tyk Environment 2"
log_start_deployment
bootstrap_progress

dashboard2_base_url="http://localhost:3002"
gateway2_base_url="http://localhost:8085"

log_message "Waiting for Tyk 2 Dashboard to respond ok"
dashboard_admin_api_credentials=$(cat deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf | jq -r .admin_secret)
wait_for_response "$dashboard2_base_url/admin/organisations" "200" "admin-auth: $dashboard_admin_api_credentials"

log_message "Importing organisation"
log_json_result "$(curl $dashboard2_base_url/admin/organisations/import -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @deployments/tyk/data/tyk-dashboard/organisation.json)"
bootstrap_progress

log_message "Creating Dashboard user"
dashboard_user_email=$(jq -r '.email_address' deployments/tyk/data/tyk-dashboard/dashboard-user.json)
dashboard_user_password=$(jq -r '.password' deployments/tyk/data/tyk-dashboard/dashboard-user.json)
dashboard2_user_api_response=$(curl $dashboard2_base_url/admin/users -s \
  -H "admin-auth: $dashboard_admin_api_credentials" \
  -d @deployments/tyk/data/tyk-dashboard/dashboard-user.json 2>> bootstrap.log \
  | jq -r '. | {api_key:.Message, id:.Meta.id}')
dashboard2_user_id=$(echo $dashboard2_user_api_response | jq -r '.id')
dashboard2_user_api_credentials=$(echo $dashboard2_user_api_response | jq -r '.api_key')
log_message "  Tyk 2 Dashboard User API Credentials = $dashboard2_user_api_credentials"
bootstrap_progress

log_message "Recording Dashboard user API credentials"
echo $dashboard2_user_api_credentials > .context-data/dashboard2-user-api-credentials
log_ok
bootstrap_progress

log_message "Resetting Dashboard user password"
log_json_result "$(curl $dashboard2_base_url/api/users/$dashboard2_user_id/actions/reset -s \
  -H "authorization: $dashboard2_user_api_credentials" \
  --data-raw '{
      "new_password":"'$dashboard_user_password'",
      "user_permissions": { "IsAdmin": "admin" }
    }')"
bootstrap_progress

log_end_deployment

echo -e "\033[2K 
▼ Tyk Environment 2
  ▽ Dashboard 
               URL : $dashboard2_base_url
          Username : $dashboard_user_email
          Password : $dashboard_user_password
   API Credentials : $dashboard2_user_api_credentials
  ▽ Gateway 
               URL : $gateway2_base_url"