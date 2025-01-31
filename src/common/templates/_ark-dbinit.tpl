{{- /*
Render the boot order configuration file to be consumed by the init container
that checks the boot order
*/ -}}
{{- define "arkcase.initDatabase.render" -}}
  {{- $declaration := dict -}}
  {{- if and (hasKey .Values "dbinit") (.Values.dbinit) -}}
    {{- $declaration = .Values.dbinit -}}
  {{- end -}}
  {{- if not (kindIs "map" $declaration) -}}
    {{- fail (printf "The .Values.dbinit value must be a map data structure (%s)" (kindOf $declaration)) -}}
  {{- end -}}

  {{- $dbInit := dict -}}
  {{- $secretEntries := dict -}}
  {{- $secret := (dict "name" (printf "%s-database-init" (include "arkcase.fullname" .))) -}}

  {{- if and (hasKey $declaration "admin") $declaration.admin -}}
    {{- /* Sanitize the admin object */ -}}
    {{- $admin := $declaration.admin -}}
    {{- /* Verify that the admin password information is set properly */ -}}
    {{- if kindIs "string" $admin -}}
      {{- $admin = dict "password" $admin -}}
    {{- end -}}
    {{- if kindIs "map" $admin -}}
      {{- if not (hasKey $admin "password") -}}
        {{- $admin = set $admin "password" (sha1sum "admin") -}}
      {{- end -}}
      {{- $password := $admin.password -}}
      {{- if (kindIs "string" $password) -}}
        {{- $key := "__ADMIN_PASSWORD__" -}}
        {{- $secretEntries = set $secretEntries $key $password -}}
        {{- $password = (dict "secretName" $secret.name "secretKey" $key) -}}
      {{- end -}}
      {{- if (kindIs "map" $password) -}}
        {{- /* If this is a map, validate its contents */ -}}
        {{- if not (hasKey $password "secretName") -}}
          {{- fail "The .Values.dbinit.admin.password map doesn't have a secretName" -}}
        {{- end -}}
        {{- if not (hasKey $password "secretKey") -}}
          {{- fail "The .Values.dbinit.admin.password map doesn't have a secretKey" -}}
        {{- end -}}
        {{- $password = set $password "secretName" ($password.secretName | toString) -}}
        {{- $password = set $password "secretKey" ($password.secretKey | toString) -}}
        {{- $admin = set $admin "password" $password -}}
      {{- else -}}
        {{- fail "The value for .Values.dbinit.admin.password must be either a map or a string" -}}
      {{- end -}}
      {{- $dbInit = set $dbInit "admin" $admin -}}
    {{- else -}}
      {{- fail "The value for .Values.dbinit.admin must be either a map or a string" -}}
    {{- end -}}
  {{- end -}}

  {{- /* Sanitize the user list */ -}}
  {{- if hasKey $declaration "users" -}}
    {{- if not (kindIs "map" $declaration.users) -}}
      {{- fail "The .Values.dbinit.users object must be a map" -}}
    {{- end -}}
    {{- $users := dict -}}
    {{- range $userName, $userData := $declaration.users -}}
      {{- /* TODO: validate the username */ -}}
      {{- if not (regexMatch "^.*$" $userName) -}}
        {{- fail (printf "The username [%s] is not a valid username" $userName) -}}
      {{- end -}}
      {{- if or (kindIs "string" $userData) (not $userData) -}}
        {{- $userData = dict "password" $userData -}}
      {{- end -}}
      {{- if kindIs "map" $userData -}}
        {{- if not (hasKey $userData "password") -}}
          {{- $userData = set $userData "password" (sha1sum $userName) -}}
        {{- end -}}
        {{- $password := $userData.password -}}
        {{- if (kindIs "string" $password) -}}
          {{- $secretEntries = set $secretEntries $userName $password -}}
          {{- $password = (dict "secretName" $secret.name "secretKey" $userName) -}}
        {{- end -}}
        {{- if (kindIs "map" $password) -}}
          {{- /* If this is a map, validate its contents */ -}}
          {{- if not (hasKey $password "secretName") -}}
            {{- fail (printf "The .Values.dbinit.users[%s].password map doesn't have a secretName" $userName) -}}
          {{- end -}}
          {{- if not (hasKey $password "secretKey") -}}
            {{- fail (printf "The .Values.dbinit.users[%s].password map doesn't have a secretKey" $userName) -}}
          {{- end -}}
          {{- $userData = set $userData "password" (dict "secretName" ($password.secretName | toString) "secretKey" ($password.secretKey | toString)) -}}
        {{- else -}}
          {{- fail (printf "The value for .Values.dbinit.users[%s].password must either be a map or a string" $userName) -}}
        {{- end -}}
      {{- else -}}
        {{- fail (printf "The .Values.dbinit.users[%s] object must be a map or a string" $userName) -}}
      {{- end -}}
      {{- if $userData -}}
        {{- $users = set $users $userName $userData -}}
      {{- end -}}
    {{- end -}}
    {{- if $users -}}
      {{- $dbInit = set $dbInit "users" $users -}}
    {{- end -}}
  {{- end -}}

  {{- /* Sanitize the database declarations */ -}}
  {{- if hasKey $declaration "databases" -}}
    {{- if not (kindIs "map" $declaration.databases) -}}
      {{- fail "The .Values.dbinit.databases object must be a map" -}}
    {{- end -}}
    {{- $databases := $declaration.databases -}}
    {{- range $dbName, $dbData := $databases -}}
      {{- /* TODO: validate the database name */ -}}
      {{- if not (regexMatch "^.*$" $dbName) -}}
        {{- fail (printf "The database name [%s] is not a valid database name" $dbName) -}}
      {{- end -}}
      {{- if kindIs "map" $dbData -}}
        {{- if hasKey $dbData "schemas" -}}
          {{- if not (kindIs "map" $dbData.schemas) -}}
            {{- fail (printf "The .Values.dbinit.databases.%s.schemas object must be a map" $dbName) -}}
          {{- end -}}
          {{- $schemas := $dbData.schemas -}}
          {{- range $schemaName, $schemaData := $schemas -}}
            {{- /* TODO: validate the schema name */ -}}
            {{- if not (regexMatch "^.*$" $schemaName) -}}
              {{- fail (printf "The schema name [%s] is not a valid schema name" $schemaName) -}}
            {{- end -}}
            {{- if $schemaData -}}
              {{- $schemas = set $schemas $schemaName $schemaData -}}
            {{- end -}}
          {{- end -}}
          {{- if $schemas -}}
            {{- $dbData = set $dbData "schemas" $schemas -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
      {{- if $dbData -}}
        {{- $databases = set $databases $dbName $dbData -}}
      {{- end -}}
    {{- end -}}
    {{- if $databases -}}
      {{- $dbInit = set $dbInit "databases" $databases -}}
    {{- end -}}
  {{- end -}}

  {{- /* Sanitize the script declarations */ -}}
  {{- if hasKey $declaration "scripts" -}}
    {{- if not (kindIs "slice" $declaration.scripts) -}}
      {{- fail "The .Values.dbinit.scripts object must be an array (list)" -}}
    {{- end -}}
    {{- $scripts := list -}}
    {{- $pos := 0 -}}
    {{- range $script := $declaration.scripts -}}
      {{- $pos = add $pos 1 -}}
      {{- /* validate each script */ -}}
      {{- if kindIs "map" $script -}}
        {{- $map := dict -}}
        {{- $query := $script.query -}}
        {{- if $query -}}
          {{- $map = set $map "query" ($query | toString) -}}
        {{- end -}}
        {{- $file := $script.file -}}
        {{- if $file -}}
          {{- $map = set $map "file" ($file | toString) -}}
        {{- end -}}
        {{- $url := $script.url -}}
        {{- if $url -}}
          {{- $map = set $map "url" ($url | toString) -}}
        {{- end -}}
        {{- if ne 1 (len (keys $map)) -}}
          {{- fail (printf "Scripts must have EXACTLY ONE of 'query', 'url', or 'file' (position %d)" $pos) -}}
        {{- end -}}

        {{- if and (hasKey $script "onlyFor") (kindIs "slice" $script.onlyFor) -}}
          {{- $onlyFor := list -}}
          {{- range $dbName := $script.onlyFor -}}
            {{- if kindIs "string" $dbName -}}
              {{- $dbName = ($dbName | lower | trim) -}}
              {{- if $dbName -}}
                {{- $onlyFor = append $onlyFor ($dbName | toString | lower) -}}
              {{- end -}}
            {{- end -}}
          {{- end -}}
          {{- if $onlyFor -}}
            {{- $script = set $script "onlyFor" $onlyFor -}}
          {{- end -}}
        {{- end -}}
      {{- else if kindIs "string" $script -}}
        {{- $script = dict "query" $script -}}
      {{- else -}}
        {{- fail (printf "Script declarations must either be a map or a string (position %d)" $pos) -}}
      {{- end -}}
      {{- if $script -}}
        {{- $scripts = append $scripts $script -}}
      {{- end -}}
    {{- end -}}
    {{- if $scripts -}}
      {{- $dbInit = set $dbInit "scripts" $scripts -}}
    {{- end -}}
  {{- end -}}

  {{- if $dbInit -}}
    {{- if $secretEntries -}}
      {{- $secret = set $secret "entries" $secretEntries -}}
    {{- else -}}
      {{- /* If there are no secrets to keep, we don't render a secret */ -}}
      {{- $secret = dict -}}
    {{- end -}}
    {{- (dict "result" (dict "config" $dbInit "secret" $secret)) | toYaml -}}
  {{- else -}}
    {{- (dict (dict "result" "" "secret" "")) | toYaml -}}
  {{- end -}}
{{- end -}}

{{- /*
Either render and cache, or fetch the cached rendering of the init dependencies configuration
in JSON format
*/ -}}
{{- define "arkcase.initDatabase.cached" -}}
  {{- $cacheKey := "InitDatabase" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ $cacheKey) -}}
    {{- $masterCache = get $ $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $crap := set $ $cacheKey $masterCache -}}

  {{- $chartName := (include "arkcase.fullname" $) -}}
  {{- if not (hasKey $masterCache $chartName) -}}
    {{- $obj := get (include "arkcase.initDatabase.render" . | fromYaml) "result" -}}
    {{- if not $obj -}}
      {{- $obj = dict -}}
    {{- end -}}
    {{- $masterCache = set $masterCache $chartName $obj -}}
  {{- end -}}
  {{- get $masterCache $chartName | toYaml -}}
{{- end -}}

{{- define "arkcase.initDatabase.yaml" -}}
  {{- get ((include "arkcase.initDatabase.cached" .) | fromYaml) "config" | toYaml -}}
{{- end -}}

{{- define "arkcase.initDatabase.json" -}}
  {{- (include "arkcase.initDatabase.yaml" .) | fromYaml | mustToPrettyJson -}}
{{- end -}}

{{- define "arkcase.initDatabase" -}}
  {{- include "arkcase.initDatabase.cached" . | fromYaml | mustToPrettyJson -}}
{{- end -}}

{{- /*
Render the boot order configuration file to be consumed by the init container
that checks the boot order (remember to |bool the outcome!)
*/ -}}
{{- define "arkcase.hasInitDatabase" -}}
  {{- $yaml := (include "arkcase.initDatabase.yaml" . | fromYaml) -}}
  {{- if $yaml -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.initDatabase.container" -}}
  {{- if not (kindIs "map" .) -}}
    {{- fail "The parameter object must be a dict with a 'ctx', a 'db', a 'volume', and an optional 'name' values" -}}
  {{- end -}}
  {{- /* If we're given a parameter map, analyze it */ -}}
  {{- if or (not (hasKey . "db")) (empty .db) (not (kindIs "string" .db)) -}}
    {{- fail "The 'db' parameter must be present, a string-value, and non-empty" -}}
  {{- end -}}
  {{- $dbType := (.db | trim) -}}
  {{- if or (not (hasKey . "volume")) (empty .volume) (not (kindIs "string" .volume)) -}}
    {{- fail "The 'volume' parameter must be present, a string-value, and non-empty" -}}
  {{- end -}}
  {{- $shell := false -}}
  {{- if .shell -}}
    {{- if (kindIs "bool" .shell) -}}
      {{- $shell = .shell -}}
    {{- else -}}
      {{- $shell = (eq (.shell | toString | trim | lower) "true") -}}
    {{- end -}}
  {{- end -}}
  {{- $scriptSources := (.scriptSources | default "") -}}
  {{- $volume := (.volume | trim) -}}
  {{- $containerName := "" -}}
  {{- if hasKey . "name" -}}
    {{- $containerName := (.name | toString) -}}
  {{- end -}}
  {{- if not $containerName -}}
    {{- $containerName = "database-init" -}}
  {{- end -}}
  {{- $ctx := . -}}
  {{- if hasKey . "ctx" -}}
    {{- $ctx = .ctx -}}
  {{- else -}}
    {{- $ctx = $ -}}
  {{- end -}}

  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "You must supply the 'ctx' parameter, pointing to the root context that contains 'Values' et al." -}}
  {{- end -}}

  {{- if (include "arkcase.hasInitDatabase" $ctx) -}}
    {{- $yaml := (include "arkcase.initDatabase.cached" $ctx | fromYaml) -}}
    {{- if $yaml -}}
- name: {{ $containerName | quote }}
  {{- include "arkcase.image" (dict "ctx" $ctx "name" "dbinit" "repository" "arkcase/dbinit") | nindent 2 }}
  env: {{- include "arkcase.tools.baseEnv" $ctx | nindent 4 }}
    - name: INIT_DB_TYPE
      value: {{ $dbType | quote }}
    - name: INIT_DB_CONF
      value: |- {{- $yaml.config | toYaml | nindent 8 }}
    - name: INIT_DB_STORE
      value: &dbInitStoreMount "/dbinit"
    - name: INIT_DB_SECRETS
      value: &dbInitSecretsMount "/dbsecrets"
    - name: INIT_DB_SHELL
      value: {{ $shell | quote }}
    {{- if $scriptSources }}
    - name: INIT_DB_SHELL_SOURCES
      value: {{ $scriptSources | quote }}
    {{- end }}
  volumeMounts:
    # This volume mount is required b/c this is where we'll put the rendered initialization scripts
    # that the DB container is expected to execute during startup
    - name: {{  $volume | quote  }}
      mountPath: *dbInitStoreMount
      {{- if $yaml.secret }}
    - name: {{ (printf "%s-secret" $yaml.secret.name) | quote }}
      mountPath: *dbInitSecretsMount
      {{- end }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.initDatabase.adminPassEnv" -}}
  {{- if not (kindIs "map" .) -}}
    {{- fail "The parameter object must be a dict with a 'ctx', and an optional 'var' values" -}}
  {{- end -}}

  {{- $ctx := . -}}
  {{- if hasKey . "ctx" -}}
    {{- $ctx = .ctx -}}
  {{- else -}}
    {{- $ctx = $ -}}
  {{- end -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "You must supply the 'ctx' parameter, pointing to the root context that contains 'Values' et al." -}}
  {{- end -}}

  {{- if not (hasKey . "var") -}}
    {{- fail "The 'var' parameter value is required" -}}
  {{- end -}}
  {{- $var := (.var | toString) -}}
  {{- if not ($var) -}}
    {{- fail "The 'var' parameter value may not be empty" -}}
  {{- end -}}

  {{- if (include "arkcase.hasInitDatabase" $ctx) -}}
    {{- $yaml := (include "arkcase.initDatabase.yaml" $ctx | fromYaml) -}}
    {{- if $yaml -}}
      {{- $adminPassword := ($yaml.admin).password -}}
      {{- if $adminPassword -}}
- name: {{ $var | quote }}
  valueFrom:
    secretKeyRef:
      name: {{ $adminPassword.secretName | quote }}
      key: {{ $adminPassword.secretKey | quote }}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.initDatabase.userPassEnv" -}}
  {{- if not (kindIs "map" .) -}}
    {{- fail "The parameter object must be a dict with a 'ctx', and an optional 'var' values" -}}
  {{- end -}}

  {{- $ctx := . -}}
  {{- if hasKey . "ctx" -}}
    {{- $ctx = .ctx -}}
  {{- else -}}
    {{- $ctx = $ -}}
  {{- end -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "You must supply the 'ctx' parameter, pointing to the root context that contains 'Values' et al." -}}
  {{- end -}}

  {{- if not (hasKey . "var") -}}
    {{- fail "The 'var' parameter value is required" -}}
  {{- end -}}
  {{- $var := (.var | toString) -}}
  {{- if not ($var) -}}
    {{- fail "The 'var' parameter value may not be empty" -}}
  {{- end -}}

  {{- if not (hasKey . "user") -}}
    {{- fail "The 'user' parameter value is required" -}}
  {{- end -}}
  {{- $user := (.user | toString) -}}
  {{- if not ($user) -}}
    {{- fail "The 'user' parameter value may not be empty" -}}
  {{- end -}}

  {{- if (include "arkcase.hasInitDatabase" $ctx) -}}
    {{- $yaml := (include "arkcase.initDatabase.yaml" $ctx | fromYaml) -}}
    {{- if $yaml -}}
      {{- $users := ($yaml.users) -}}
      {{- if hasKey $users $user -}}
        {{- $user = get $users $user -}}
        {{- $password := $user.password -}}
- name: {{ $var | quote }}
  valueFrom:
    secretKeyRef:
      name: {{ $password.secretName | quote }}
      key: {{ $password.secretKey | quote }}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.initDatabase.secret" -}}
  {{- if (include "arkcase.hasInitDatabase" .) -}}
    {{- $yaml := (include "arkcase.initDatabase.cached" . | fromYaml) -}}
    {{- $secret := $yaml.secret -}}
    {{- if $secret -}}
---
apiVersion: v1
kind: Secret
metadata:
  name: {{ $secret.name | quote }}
  namespace: {{ .Release.Namespace | quote }}
  labels: {{- include "common.labels" . | nindent 4 }}
    {{- with (.Values.labels).common }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    timestamp: {{ date "20060102150405" now | quote }}
    {{- with (.Values.annotations).common }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
type: Opaque
stringData:
      {{- range $key, $value := $secret.entries }}
  {{ $key | quote }}: {{ $value | quote }}
      {{- end }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "__.arkcase.initDatabase.secretVolume.name" -}}
  {{- printf "%s-secret" .name -}}
{{- end -}}

{{- define "arkcase.initDatabase.secretVolume.name" -}}
  {{- if (include "arkcase.hasInitDatabase" .) -}}
    {{- $yaml := (include "arkcase.initDatabase.cached" . | fromYaml) -}}
    {{- $secret := $yaml.secret -}}
    {{- if $secret -}}
{{ include "__.arkcase.initDatabase.secretVolume.name" $secret }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.initDatabase.secretVolume" -}}
  {{- if (include "arkcase.hasInitDatabase" .) -}}
    {{- $yaml := (include "arkcase.initDatabase.cached" . | fromYaml) -}}
    {{- $secret := $yaml.secret -}}
    {{- if $secret -}}
- name: {{ include "__.arkcase.initDatabase.secretVolume.name" $secret | quote }}
  secret:
    secretName: {{ $secret.name | quote }}
    {{- end -}}
  {{- end -}}
{{- end -}}
