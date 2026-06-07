#!/usr/bin/env bash
set -euo pipefail

REALM="${REALM:-NextLife}"
CONTAINER="${CONTAINER:-nextid}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
SERVER="${SERVER:-http://localhost:8080}"

KC() {
  docker exec -i "$CONTAINER" /opt/keycloak/bin/kcadm.sh "$@"
}

echo "Login: $SERVER / master"
KC config credentials \
  --server "$SERVER" \
  --realm master \
  --user "$ADMIN_USER" \
  --password "$ADMIN_PASSWORD"

echo "Checking realm: $REALM"
KC get realms/"$REALM" >/dev/null

client_uuid() {
  local client_id="$1"
  KC get clients -r "$REALM" -q clientId="$client_id" --fields id,clientId 2>/dev/null \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d[0]["id"] if d else "")'
}

service_account_user_id() {
  local client_id="$1"
  local cid
  cid="$(client_uuid "$client_id")"
  KC get clients/"$cid"/service-account-user -r "$REALM" --fields id 2>/dev/null \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])'
}

group_id_by_path() {
  local target="$1"
  local clean="${target#/}"
  local parent_id=""
  local segment
  local group_id
  local -a segments

  IFS="/" read -r -a segments <<< "$clean"

  for segment in "${segments[@]}"; do
    if [ -z "$parent_id" ]; then
      group_id="$(
        KC get groups -r "$REALM" --fields id,name 2>/dev/null \
          | python3 -c '
import sys, json
name = sys.argv[1]
groups = json.load(sys.stdin)
print(next((g["id"] for g in groups if g.get("name") == name), ""))
' "$segment"
      )"
    else
      group_id="$(
        KC get groups/"$parent_id"/children -r "$REALM" --fields id,name 2>/dev/null \
          | python3 -c '
import sys, json
name = sys.argv[1]
groups = json.load(sys.stdin)
print(next((g["id"] for g in groups if g.get("name") == name), ""))
' "$segment"
      )"
    fi

    [ -n "$group_id" ] || return 1
    parent_id="$group_id"
  done

  printf '%s\n' "$parent_id"
}

ensure_group() {
  local target="/${1#/}"
  local existing
  existing="$(group_id_by_path "$target" || true)"
  if [ -n "$existing" ]; then
    echo "$existing"
    return
  fi

  local clean="${target#/}"
  if [[ "$clean" != */* ]]; then
    KC create groups -r "$REALM" -s name="$clean" >/dev/null 2>&1 || true
  else
    local parent="/${clean%/*}"
    local name="${clean##*/}"
    local parent_id
    parent_id="$(ensure_group "$parent")"
    KC create groups/"$parent_id"/children -r "$REALM" -s name="$name" >/dev/null 2>&1 || true
  fi

  group_id_by_path "$target"
}

ensure_realm_role() {
  local role="$1"
  KC create roles -r "$REALM" -s name="$role" >/dev/null 2>&1 || true
}

ensure_client() {
  local client_id="$1"
  local name="$2"
  local service_account="$3"
  local standard_flow="$4"
  local direct_grant="$5"

  local id
  id="$(client_uuid "$client_id")"

  if [ -z "$id" ]; then
    KC create clients -r "$REALM" \
      -s clientId="$client_id" \
      -s name="$name" \
      -s enabled=true \
      -s publicClient=false \
      -s protocol=openid-connect \
      -s standardFlowEnabled="$standard_flow" \
      -s directAccessGrantsEnabled="$direct_grant" \
      -s serviceAccountsEnabled="$service_account" >/dev/null
  else
    KC update clients/"$id" -r "$REALM" \
      -s name="$name" \
      -s enabled=true \
      -s publicClient=false \
      -s standardFlowEnabled="$standard_flow" \
      -s directAccessGrantsEnabled="$direct_grant" \
      -s serviceAccountsEnabled="$service_account" >/dev/null
  fi
}

ensure_client_role() {
  local client_id="$1"
  local role="$2"
  local cid
  cid="$(client_uuid "$client_id")"
  KC create clients/"$cid"/roles -r "$REALM" -s name="$role" >/dev/null 2>&1 || true
}

assign_realm_roles_to_group() {
  local group_path="$1"
  shift
  local gid
  gid="$(ensure_group "$group_path")"
  for role in "$@"; do
    KC add-roles -r "$REALM" --gid "$gid" --rolename "$role" >/dev/null 2>&1 || true
  done
}

assign_client_roles_to_group() {
  local group_path="$1"
  local client_id="$2"
  shift 2
  local gid
  gid="$(ensure_group "$group_path")"
  for role in "$@"; do
    KC add-roles -r "$REALM" --gid "$gid" --cclientid "$client_id" --rolename "$role" >/dev/null 2>&1 || true
  done
}

assign_client_roles_to_service_account() {
  local service_client_id="$1"
  local role_client_id="$2"
  shift 2
  local user_id
  user_id="$(service_account_user_id "$service_client_id")"
  for role in "$@"; do
    KC add-roles -r "$REALM" --uid "$user_id" --cclientid "$role_client_id" --rolename "$role" >/dev/null 2>&1 || true
  done
}

echo "Creating realm roles..."
for role in \
  NEXTID_SUPERADMIN \
  NEXTID_ADMIN \
  NEXTID_APP_SUPERADMIN \
  NEXTID_USER_LIFECYCLE_MANAGER \
  NEXTID_USER_ACTIVATOR \
  NEXTID_USER_DEACTIVATOR \
  NEXTID_ACCESS_MANAGER \
  NEXTID_DEVELOPER \
  NEXTID_AUDITOR \
  NEXTID_SUPPORT \
  NEXTID_USER \
  NEXTID_STUDENT \
  NEXTID_EMPLOYEE \
  NEXTID_ACADEMIC_STAFF \
  NEXTID_ADMINISTRATIVE_STAFF \
  NEXTID_EXTERNAL_USER \
  NEXTID_GUEST
do
  ensure_realm_role "$role"
done

echo "Creating clients..."
ensure_client "nextid-admin-api" "NextId Admin API" true false false
ensure_client "nextvote" "NextVote" false true true
ensure_client "nexttask" "NextTask" false true true
ensure_client "nextcollect" "NextCollect" false true true

echo "Creating client roles..."
for role in ADMIN MANAGER OPERATOR VIEWER USER CREATE_ELECTION APPROVE_ELECTION VIEW_RESULTS EXPORT_RESULTS; do
  ensure_client_role nextvote "$role"
done

for role in ADMIN MANAGER ASSIGNEE VIEWER USER CREATE_TASK ASSIGN_TASK UPDATE_TASK VIEW_REPORTS; do
  ensure_client_role nexttask "$role"
done

for role in ADMIN DATA_ENTRY DATA_APPROVER REPORT_VIEWER REPORT_MANAGER USER APPROVE_DATA EXPORT_REPORT; do
  ensure_client_role nextcollect "$role"
done

echo "Creating group tree..."
for g in \
  /system \
  /system/superadmins \
  /system/admins \
  /system/user-lifecycle-managers \
  /system/developers \
  /system/auditors \
  /system/support \
  /affiliations \
  /affiliations/students \
  /affiliations/academic-staff \
  /affiliations/administrative-staff \
  /affiliations/external-users \
  /affiliations/guests \
  /apps \
  /apps/appsuperadmins \
  /apps/nextvote \
  /apps/nextvote/admins \
  /apps/nextvote/managers \
  /apps/nextvote/operators \
  /apps/nextvote/viewers \
  /apps/nextvote/users \
  /apps/nexttask \
  /apps/nexttask/admins \
  /apps/nexttask/managers \
  /apps/nexttask/assignees \
  /apps/nexttask/viewers \
  /apps/nexttask/users \
  /apps/nextcollect \
  /apps/nextcollect/admins \
  /apps/nextcollect/data-entry \
  /apps/nextcollect/data-approvers \
  /apps/nextcollect/report-viewers \
  /apps/nextcollect/report-managers \
  /apps/nextcollect/users
do
  ensure_group "$g" >/dev/null
done

echo "Assigning system roles..."
assign_realm_roles_to_group /system/superadmins NEXTID_SUPERADMIN NEXTID_APP_SUPERADMIN NEXTID_ADMIN NEXTID_USER
assign_client_roles_to_group /system/superadmins realm-management realm-admin

assign_realm_roles_to_group /system/admins NEXTID_ADMIN NEXTID_USER
assign_realm_roles_to_group /system/user-lifecycle-managers NEXTID_USER_LIFECYCLE_MANAGER NEXTID_USER_ACTIVATOR NEXTID_USER_DEACTIVATOR NEXTID_ACCESS_MANAGER NEXTID_USER
assign_realm_roles_to_group /system/developers NEXTID_DEVELOPER NEXTID_USER
assign_realm_roles_to_group /system/auditors NEXTID_AUDITOR NEXTID_USER
assign_realm_roles_to_group /system/support NEXTID_SUPPORT NEXTID_USER

echo "Assigning affiliation roles..."
assign_realm_roles_to_group /affiliations/students NEXTID_STUDENT NEXTID_USER
assign_realm_roles_to_group /affiliations/academic-staff NEXTID_EMPLOYEE NEXTID_ACADEMIC_STAFF NEXTID_USER
assign_realm_roles_to_group /affiliations/administrative-staff NEXTID_EMPLOYEE NEXTID_ADMINISTRATIVE_STAFF NEXTID_USER
assign_realm_roles_to_group /affiliations/external-users NEXTID_EXTERNAL_USER NEXTID_USER
assign_realm_roles_to_group /affiliations/guests NEXTID_GUEST NEXTID_USER

echo "Assigning app roles..."
assign_realm_roles_to_group /apps/appsuperadmins NEXTID_APP_SUPERADMIN NEXTID_USER

assign_client_roles_to_group /apps/nextvote/admins nextvote ADMIN CREATE_ELECTION APPROVE_ELECTION VIEW_RESULTS EXPORT_RESULTS
assign_client_roles_to_group /apps/nextvote/managers nextvote MANAGER CREATE_ELECTION VIEW_RESULTS
assign_client_roles_to_group /apps/nextvote/operators nextvote OPERATOR CREATE_ELECTION
assign_client_roles_to_group /apps/nextvote/viewers nextvote VIEWER VIEW_RESULTS
assign_client_roles_to_group /apps/nextvote/users nextvote USER

assign_client_roles_to_group /apps/nexttask/admins nexttask ADMIN CREATE_TASK ASSIGN_TASK UPDATE_TASK VIEW_REPORTS
assign_client_roles_to_group /apps/nexttask/managers nexttask MANAGER CREATE_TASK ASSIGN_TASK VIEW_REPORTS
assign_client_roles_to_group /apps/nexttask/assignees nexttask ASSIGNEE UPDATE_TASK
assign_client_roles_to_group /apps/nexttask/viewers nexttask VIEWER VIEW_REPORTS
assign_client_roles_to_group /apps/nexttask/users nexttask USER

assign_client_roles_to_group /apps/nextcollect/admins nextcollect ADMIN DATA_ENTRY DATA_APPROVER REPORT_VIEWER REPORT_MANAGER APPROVE_DATA EXPORT_REPORT
assign_client_roles_to_group /apps/nextcollect/data-entry nextcollect DATA_ENTRY
assign_client_roles_to_group /apps/nextcollect/data-approvers nextcollect DATA_APPROVER APPROVE_DATA
assign_client_roles_to_group /apps/nextcollect/report-viewers nextcollect REPORT_VIEWER
assign_client_roles_to_group /apps/nextcollect/report-managers nextcollect REPORT_MANAGER EXPORT_REPORT
assign_client_roles_to_group /apps/nextcollect/users nextcollect USER

echo "Granting admin service-account permissions to nextid-admin-api..."
assign_client_roles_to_service_account nextid-admin-api realm-management view-users query-users query-groups manage-users view-realm

echo "Done."
