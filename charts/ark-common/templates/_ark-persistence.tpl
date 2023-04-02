{{- define "arkcase.persistence.getSetting" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $name := .name -}}
  {{- if or (not $name) (not (kindIs "string" $name)) -}}
    {{- fail "The 'name' parameter must be the name of the setting to retrieve" -}}
  {{- end -}}
  {{- $result := dict -}}

  {{- $global :=(($ctx.Values.global).persistence | default dict) -}}
  {{- if (hasKey $global $name) -}}
    {{- $result = set $result "global" (get $global $name) -}}
  {{- end -}}

  {{- $local := ($ctx.Values.persistence | default dict) -}}
  {{- if (hasKey $local $name) -}}
    {{- $result = set $result "local" (get $local $name) -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- /* Check if persistence is enabled, assuming a missing setting defaults to true */ -}}
{{- define "arkcase.persistence.enabled" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $local := (include "arkcase.tools.checkEnabledFlag" (.Values.persistence | default dict)) -}}
  {{- $global := (include "arkcase.tools.checkEnabledFlag" ((.Values.global).persistence | default dict)) -}}

  {{- /* Persistence is only enabled if the local and global flags agree that it should be */ -}}
  {{- if (and $local $global) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /* Get the rootPath value that should be used for everything */ -}}
{{- define "arkcase.persistence.rootPath" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $rootPath := (include "arkcase.persistence.getSetting" (dict "ctx" . "name" "rootPath") | fromYaml) -}}
  {{- coalesce $rootPath.global $rootPath.local "/opt/app" -}}
{{- end -}}

{{- /* Get the storageClass value that should be used for everything */ -}}
{{- define "arkcase.persistence.storageClass" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $values := (include "arkcase.persistence.getSetting" (dict "ctx" . "name" "storageClass") | fromYaml) -}}
  {{- $storageClass := "" -}}
  {{- $storageClassSet := false -}}
  {{- if and (not $storageClassSet) (hasKey $values "global") -}}
    {{- $storageClass = $values.global -}}
    {{- if and $storageClass (not (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]$" ($storageClass | lower))) -}}
      {{- fail (printf "The value global.persistence.storageClass must be a valid storage class name: [%s]" $storageClass) -}}
    {{- end -}}
    {{- $storageClassSet = true -}}
  {{- end -}}
  {{- if and (not $storageClassSet) (hasKey $values "local") -}}
    {{- $storageClass = $values.local -}}
    {{- if and $storageClass (not (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]$" ($storageClass | lower))) -}}
      {{- fail (printf "The value persistence.storageClass must be a valid storage class name: [%s]" $storageClass) -}}
    {{- end -}}
    {{- $storageClassSet = true -}}
  {{- end -}}
  {{- /* Only output a value if one is set */ -}}
  {{- if $storageClass -}}
    {{- $storageClass -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.persistentVolumeReclaimPolicy" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $values := (include "arkcase.persistence.getSetting" (dict "ctx" . "name" "persistentVolumeReclaimPolicy") | fromYaml) -}}
  {{- $policy := "" -}}
  {{- if and (not $policy) (hasKey $values "global") -}}
    {{- $policy = $values.global -}}
    {{- if and $policy (not (regexMatch "^(retain|recycle|delete)$" ($policy | lower))) -}}
      {{- fail (printf "The value global.persistence.persistentVolumeReclaimPolicy must be a valid persistent volume reclaim policy (Retain/Recycle/Delete): [%s]" $policy) -}}
    {{- end -}}
  {{- end -}}
  {{- if and (not $policy) (hasKey $values "local") -}}
    {{- $policy = $values.local -}}
    {{- if and $policy (not (regexMatch "^(retain|recycle|delete)$" ($policy | lower))) -}}
      {{- fail (printf "The value persistence.persistentVolumeReclaimPolicy must be a valid persistent volume reclaim policy (Retain/Recycle/Delete): [%s]" $policy) -}}
    {{- end -}}
  {{- end -}}
  {{- if $policy -}}
    {{- $policy | lower | title -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.accessModes" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $values := (include "arkcase.persistence.getSetting" (dict "ctx" . "name" "accessModes") | fromYaml) -}}
  {{- $modes := dict -}}
  {{- if and (not $modes) (hasKey $values "global") -}}
    {{- $accessModes = $values.global -}}
    {{- $str := "" -}}
    {{- if kindIs "slice" $accessModes -}}
      {{- $str = join "," $accessModes -}}
    {{- else -}}
      {{- $str := ($accessModes | toString) -}}
    {{- end -}}
    {{- $modes = (include "arkcase.persistence.buildVolume.parseAccessModes" $str) -}}
    {{- if $modes.errors -}}
      {{- fail (printf "Invalid access modes found in the value global.persistence.accessModes: %s" $modes.errors) -}}
    {{- end -}}
  {{- end -}}
  {{- if and (not $modes) (hasKey $values "local") -}}
    {{- $accessModes = $values.local -}}
    {{- $str := "" -}}
    {{- if kindIs "slice" $accessModes -}}
      {{- $str = join "," $accessModes -}}
    {{- else -}}
      {{- $str := ($accessModes | toString) -}}
    {{- end -}}
    {{- $modes = (include "arkcase.persistence.buildVolume.parseAccessModes" $str) -}}
    {{- if $modes.errors -}}
      {{- fail (printf "Invalid access modes found in the value persistence.accessModes: %s" $modes.errors) -}}
    {{- end -}}
  {{- end -}}
  {{- if $modes.modes -}}
    {{- $modes.modes | compact | join "," -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.capacity" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $values := (include "arkcase.persistence.getSetting" (dict "ctx" . "name" "capacity") | fromYaml) -}}
  {{- $capacity := "" -}}
  {{- if and (not $capacity) (hasKey $values "global") -}}
    {{- $capacity = (include "arkcase.persistence.buildVolume.parseStorageSize" $values.global | fromYaml) -}}
    {{- if not $capacity -}}
      {{- fail (printf "The value global.persistence.capacity must be a valid persistent volume capacity: [%s]" $values.global) -}}
    {{- end -}}
    {{- $capacity = $values.global -}}
  {{- end -}}
  {{- if and (not $capacity) (hasKey $values "local") -}}
    {{- $capacity = (include "arkcase.persistence.buildVolume.parseStorageSize" $values.local | fromYaml) -}}
    {{- if not $capacity -}}
      {{- fail (printf "The value persistence.capacity must be a valid persistent volume capacity: [%s]" $values.local) -}}
    {{- end -}}
    {{- $capacity = $values.local -}}
  {{- end -}}
  {{- if $capacity -}}
    {{- $capacity -}}
  {{- end -}}
{{- end -}}

{{- /* Get or define the shared persistence settings for this chart */ -}}
{{- define "arkcase.persistence.settings" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $cacheKey := "PersistenceSettings" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey . $cacheKey) -}}
    {{- $masterCache = get . $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $crap := set . $cacheKey $masterCache -}}

  {{- /* We specifically don't use arkcase.fullname here b/c we don't care about part names for this */ -}}
  {{- $chartName := (include "common.fullname" .) -}}
  {{- if not (hasKey $masterCache $chartName) -}}
    {{- $enabled := (eq "true" (include "arkcase.persistence.enabled" . | trim | lower)) -}}
    {{- $rootPath := (include "arkcase.persistence.rootPath" .) -}}
    {{- $storageClass := (include "arkcase.persistence.storageClass" .) -}}
    {{- $persistentVolumeReclaimPolicy := (include "arkcase.persistence.persistentVolumeReclaimPolicy" .) -}}
    {{- if not $persistentVolumeReclaimPolicy -}}
      {{- $persistentVolumeReclaimPolicy = "Retain" -}}
    {{- end -}}
    {{- $accessModes := (include "arkcase.persistence.accessModes" .) -}}
    {{- if $accessModes -}}
      {{- $accessModes = splitList "," $accessModes | compact -}}
    {{- end -}}
    {{- if not $accessModes -}}
      {{- /* If no access modes are given by default, use ReadWriteOnce */ -}}
      {{- $accessModes = list "ReadWriteOnce" -}}
    {{- end -}}
    {{- $capacity := (include "arkcase.persistence.capacity" .) -}}
    {{- if not $capacity -}}
      {{- $capacity = "1Gi" -}}
    {{- end -}}

    {{- $mode := "ephemeral" -}}
    {{- if $enabled -}}
      {{- if $storageClass -}}
        {{- $mode = "production" -}}
      {{- else -}}
        {{- $mode = "development" -}}
      {{- end -}}
    {{- end -}}
    {{-
      $obj := dict 
        "enabled" $enabled
        "rootPath" $rootPath
        "capacity" $capacity
        "storageClass" $storageClass
        "persistentVolumeReclaimPolicy" $persistentVolumeReclaimPolicy
        "accessModes" $accessModes
        "mode" $mode
    -}}
    {{- $masterCache = set $masterCache $chartName $obj -}}
  {{- end -}}
  {{- get $masterCache $chartName | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.sanitizeAccessMode" -}}
  {{- $M := (. | upper) -}}
  {{- if or (eq "RWO" $M) (eq "READWRITEONCE" $M) -}}
    {{- "ReadWriteOnce" -}}
  {{- else if or (eq "RWM" $M) (eq "READWRITEMANY" $M) -}}
    {{- "ReadWriteMany" -}}
  {{- else if or (eq "ROM" $M) (eq "READONLYMANY" $M) -}}
    {{- "ReadOnlyMany" -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseAccessModes" -}}
  {{- $modes := list -}}
  {{- $errors := dict -}}
  {{- $modeMap := dict -}}
  {{- range $m := splitList "," . -}}
    {{- $M := (include "arkcase.persistence.buildVolume.sanitizeAccessMode" (trim $m)) -}}
    {{- if $M -}}
      {{- if not (hasKey $modeMap $M) -}}
        {{- $modes = append $modes $M -}}
        {{- $modeMap = set $modeMap $M $M -}}
      {{- end -}}
    {{- else if $m -}}
      {{- $errors = set $errors $m $m -}}
    {{- end -}}
  {{- end -}}
  {{- dict "modes" $modes "errors" (keys $errors | sortAlpha) | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseStorageSize" -}}
  {{- $min := "" -}}
  {{- $max := "" -}}
  {{- $data := (. | upper) -}}
  {{- $result := dict -}}
  {{- if regexMatch "^[1-9][0-9]*[EPTGMK]I?(-[1-9][0-9]*[EPTGMK]I?)?$" $data -}}
    {{- $parts := split "-" $data -}}
    {{- $min = $parts._0 | replace "I" "i" | replace "K" "k" -}}
    {{- $max = $parts._1 | replace "I" "i" | replace "K" "k" -}}
    {{- $result = dict "min" $min "max" $max -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseVolumeString.pv" -}}
  {{- /* pv://[${storageClass}]/${capacity}#${accessModes} */ -}}
  {{- $data := .data -}}
  {{- $volumeName := .volumeName -}}
  {{- $pv := urlParse $data -}}
  {{- /* Perform QC: may have a storageClass, must have a capacity and accessModes */ -}}
  {{- $storageClass := $pv.host | default "" -}}
  {{- $cap := $pv.path | default "" -}}
  {{- $mode := $pv.fragment | default "" -}}
  {{- if or (not $cap) (not $mode) -}}
    {{- fail (printf "The pv:// volume declaration for '%s' must be of the form: pv://[${storageClass}]/${capacity}#${accessModes} where only the ${storageClass} portion is optional: [%s]" $volumeName $data) -}}
  {{- end -}}
  {{- $mode = (include "arkcase.persistence.buildVolume.parseAccessModes" $mode | fromYaml) -}}
  {{- if $mode.errors -}}
    {{- fail (printf "Invalid access modes %s given for volume spec '%s': [%s]" $mode.errors $volumeName $data) -}}
  {{- end -}}
  {{- $cap = (clean $cap | trimPrefix "/") -}}
  {{- $capacity := (include "arkcase.persistence.buildVolume.parseStorageSize" $cap | fromYaml) -}}
  {{- if or (not $capacity) $capacity.max -}}
    {{- fail (printf "Invalid capacity specification %s for volume '%s': [%s]" $cap $volumeName $data) -}}
  {{- end -}}
  {{- dict "render" (dict "volume" true "claim" true) "storageClass" $storageClass "capacity" $capacity.min "accessModes" $mode.modes | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseVolumeString.pvc" -}}
  {{- /* pvc://[${storageClass}]/[${minSize}][-${maxSize}]#${accessModes} */ -}}
  {{- /* pvc://volumeName#${accessModes} */ -}}
  {{- /* pvc://pvcName */ -}}
  {{- $data := .data -}}
  {{- $volumeName := .volumeName -}}
  {{- $pvc := urlParse $data -}}
  {{- if or $pvc.query $pvc.userinfo $pvc.opaque -}}
    {{- fail (printf "Malformed URI for volume '%s': [%s] - may not have userInfo, query, or opaque data" $volumeName $data) -}}
  {{- end -}}

  {{- $mode := dict -}}
  {{- if $pvc.fragment -}}
    {{- $mode = (include "arkcase.persistence.buildVolume.parseAccessModes" $pvc.fragment | fromYaml) -}}
    {{- if $mode.errors -}}
      {{- fail (printf "Invalid access modes %s given for volume spec '%s': [%s]" $mode.errors $volumeName $data) -}}
    {{- end -}}
  {{- end -}}

  {{- if and $pvc.host (not (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]$" ($pvc.host | lower))) -}}
    {{- fail (printf "Volume '%s' has an invalid first component: [%s]" $volumeName $pvc.host) -}}
  {{- end -}}

  {{- /* If we have a path, then we can only be creating a new claim b/c it's the size spec */ -}}
  {{- $volume := dict -}}
  {{- if $pvc.path -}}
    {{- /* pvc://[${storageClass}]/[${minSize}][-${maxSize}]#${accessModes} */ -}}
    {{- $limitsRequests := (clean $pvc.path | trimPrefix "/") -}}
    {{- $size := (include "arkcase.persistence.buildVolume.parseStorageSize" $limitsRequests | fromYaml) -}}
    {{- if not $size -}}
      {{- fail (printf "Invalid limits-requests specification '%s' for volume '%s': [%s]" $limitsRequests $volumeName $data) -}}
    {{- end -}}
    {{- $resources := dict "requests" (dict "storage" $size.min) -}}
    {{- if $size.max -}}
      {{- $resources = set $resources "limits" (dict "storage" $size.max) -}}
    {{- end -}}
    {{- $volume = dict "render" (dict "volume" false "claim" true) "storageClassName" $pvc.host "accessModes" $mode.modes "resources" $resources -}}
  {{- else if $pvc.fragment -}}
    {{- /* pvc://volumeName#${accessModes} */ -}}
    {{- $volume = dict "render" (dict "volume" false "claim" true) "volumeName" $volume "accessModes" $mode.modes -}}
  {{- else -}}
    {{- /* pvc://pvcName */ -}}
    {{- $volume = dict "render" (dict "volume" false "claim" false) "claimName" $pvc.host -}}
  {{- end -}}
  {{- $volume | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseVolumeString.path" -}}
  {{- $data := .data -}}
  {{- $volumeName := .volumeName -}}
  {{- /* Must be a path ... only valid in development mode */ -}}
  {{- if isAbs $data -}}
    {{- $data = (include "arkcase.tools.normalizePath" $data) -}}
  {{- else -}}
    {{- $data = (include "arkcase.tools.normalizePath" $data) -}}
    {{- if not $data -}}
      {{- fail (printf "The given relative path [%s] for volume '%s' overflows containment (too many '..' components)" .data $volumeName) -}}
    {{- end -}}
  {{- end -}}
  {{- dict "render" (dict "volume" true "claim" true) "hostPath" $data | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseVolumeString" -}}
  {{- /* Must be a pv://, pvc://, or path ... the empty string renders a default volume */ -}}
  {{- $data := .data -}}
  {{- $volumeName := .volumeName -}}
  {{- $volume := dict -}}
  {{- if $data -}}
    {{- if hasPrefix "pv://" $data -}}
      {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.pv" . | fromYaml) -}}
    {{- else if hasPrefix "pvc://" $data -}}
      {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.pvc" . | fromYaml) -}}
    {{- else -}}
      {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.path" . | fromYaml) -}}
    {{- end -}}
  {{- end -}}
  {{- $volume | toYaml -}}
{{- end -}}

{{- /*
Parse a volume declaration and return a map that contains the following (possible) keys:
  claim: the PVC that must be rendered, or the name of the PVC that must be used
  volume: the PV that must be rendered
*/ -}}
{{- define "arkcase.persistence.buildVolume.cached" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- if not (hasKey . "name") -}}
    {{- fail "Must provide the 'name' parameter for the volume to be built" -}}
  {{- end -}}
  {{- /* The volume's name will be of the form "[${part}-]$name" ($part is optional) */ -}}
  {{- $name := .name -}}
  {{- $volumeName := (printf "%s-%s" (include "arkcase.fullname" $ctx) $name) -}}
  {{- $persistence := ($ctx.Values.persistence | default dict) -}}
  {{- $persistenceVolumes := ($persistence.volumes | default dict) -}}
  {{- $data := dict -}}
  {{- if hasKey $persistenceVolumes $name -}}
    {{- $data = get $persistenceVolumes $name -}}
  {{- end -}}
  {{- $volume := dict -}}
  {{- if kindIs "string" $data -}}
    {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString" (dict "data" $data "volumeName" $volumeName) | fromYaml) -}}
  {{- else if kindIs "map" $data -}}
    {{- /* May be a map that has "path", "claim", or "volume" ... but only one! */ -}}
    {{- $data = pick $data "path" "claim" "volume" -}}
    {{- if gt (len (keys $data)) 1 -}}
      {{- fail (printf "The volume declaration for %s may only have one of the keys 'path', 'claim', or 'volume': %s" $volumeName (keys $data)) -}}
    {{- end -}}
    {{- if $data.claim -}}
      {{- if kindIs "string" $data.claim -}}
        {{- $claimStr := $data.claim -}}
        {{- if not (hasPrefix "pvc://" $claimStr) -}}
          {{- $volume = dict "render" (dict "volume" false "claim" false) "claimName" $claimStr -}}
        {{- else -}}
          {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.pvc" (dict "data" $claimStr "volumeName" $volumeName) | fromYaml) -}}
        {{- end -}}
      {{- else if kindIs "map" $data.claim -}}
        {{- $volume = (dict "render" (dict "volume" false "claim" true) "spec" $data.claim) -}}
      {{- else -}}
        {{- fail (printf "The 'claim' value for the volume '%s' must be either a dict or a string (%s)" $volumeName (kindOf $data.claim)) -}}
      {{- end -}}
    {{- else if $data.volume -}}
      {{- if kindIs "string" $data.volume -}}
        {{- if hasPrefix "pv://" $data.volume -}}
          {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.pv" (dict "data" $data.volume "volumeName" $volumeName) | fromYaml) -}}
        {{- else -}}
          {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.path" (dict "data" $data.volume "volumeName" $volumeName) | fromYaml) -}}
        {{- end -}}
      {{- else if kindIs "map" $data.volume -}}
        {{- /* The map is a volume spec, so use it */ -}}
        {{- $volume = (dict "render" (dict "volume" true "claim" true) "spec" $data.volume) -}}
      {{- else -}}
        {{- fail (printf "The 'volume' value for the volume '%s' must be either a dict or a string (%s)" $volumeName (kindOf $data.volume)) -}}
      {{- end -}}
    {{- else if $data.path -}}
      {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.path" (dict "data" $data.path "volumeName" $volumeName) | fromYaml) -}}
    {{- else -}}
      {{- $volume = (dict "render" (dict "volume" true "claim" true)) -}}
    {{- end -}}
  {{- else -}}
    {{- fail (printf "The volume declaration for %s must be either a string or a map (%s)" $volumeName (kindOf $data)) -}}
  {{- end -}}
  {{- set $volume "render" (set $volume.render "name" $volumeName) | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume" -}}
  {{- $ctx := .ctx -}}
  {{- $name := .name -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $cacheKey := "PersistenceVolumes" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ctx $cacheKey) -}}
    {{- $masterCache = get $ctx $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $ctx = set $ctx $cacheKey $masterCache -}}

  {{- /* We specifically don't use partnames here b/c we don't care about that for this */ -}}
  {{- $volumeName := (printf "%s-%s" (include "arkcase.fullname" .) $name) -}}
  {{- if not (hasKey $masterCache $volumeName) -}}
    {{- $obj := (include "arkcase.persistence.buildVolume.cached" (pick . "ctx" "name") | fromYaml) -}}
    {{- $masterCache = set $masterCache $volumeName $obj -}}
  {{- end -}}
  {{- get $masterCache $volumeName | toYaml -}}
{{- end -}}

{{- /* Verify that the persistence configuration is good */ -}}
{{- define "arkcase.persistence.validateVolumeConfig" -}}
  {{- $name := .name -}}
  {{- with .vol -}}
    {{- $hasClaimSpec := false -}}
    {{- $hasClaimName := false -}}
    {{- $hasVolumeSpec := false -}}
    {{- if (.claim) -}}
      {{- if .claim.spec -}}
        {{- $hasClaimSpec = (lt 0 (len (.claim).spec)) -}}
      {{- end -}}
      {{- if .claim.name -}}
        {{- $hasClaimName = true -}}
      {{- end -}}
      {{- if and $hasClaimName $hasClaimSpec -}}
         {{- $message := printf "The persistence definition for [%s] has both claim.name and claim.spec, choose only one" $name -}}
         {{- fail $message -}}
      {{- end -}}
    {{- end -}}
    {{- if (.spec) -}}
      {{- $hasVolumeSpec = (lt 0 (len (.spec))) -}}
    {{- end -}}
    {{- if and (or $hasClaimSpec $hasClaimName) $hasVolumeSpec -}}
       {{- $message := printf "The persistence definition for [%s] has both a claim definition and volume specifictions, choose only one" $name -}}
       {{- fail $message -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- /*
Render a volumes: entry for a given volume, as per the persistence model
*/ -}}
{{- define "arkcase.persistence.volume" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $volumeName := .name -}}
  {{- $volume := (include "arkcase.persistence.buildVolume" (pick . "ctx" "name") | fromYaml) -}}
- name: {{ $volumeName | quote }}
  {{- if (include "arkcase.persistence.enabled" $ctx) -}}
    {{- $claimName := $volume.render.name -}}
    {{- if $volume.claimName -}}
      {{- $claimName = $volume.claimName -}}
    {{- end }}
  persistentVolumeClaim:
    claimName: {{ $claimName | quote }}
  {{- else }}
  emptyDir: {}
  {{- end }}
{{- end -}}

{{- /*
Render the PersistentVolume and PersistentVolumeClaim objects for a given volume, per configurations
*/ -}}
{{- define "arkcase.persistence.declareObjects" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context" -}}
  {{- end -}}

  {{- $volumeName := .name -}}
  {{- if not $volumeName -}}
    {{- fail "Must provide the 'name' of the volume objects to declare" -}}
  {{- end -}}

  {{- if (include "arkcase.persistence.enabled" $ctx) -}}
    {{- $partname := (include "arkcase.part.name" $ctx) -}}
    {{- $settings := (include "arkcase.persistence.settings" $ctx | fromYaml) -}}
    {{- $volumeData := (include "arkcase.persistence.buildVolume" (pick . "ctx" "name") | fromYaml) -}}
    {{- $rootPath := $settings.rootPath -}}

    {{- $objectName := $volumeData.render.name -}}
    {{- $volumeObjectName := (printf "%s-%s" $ctx.Release.Namespace $objectName) -}}

    {{- $globalDefaults := (include "arkcase.tools.get" (dict "ctx" $ctx "name" ".Values.global.persistence.defaults") | fromYaml | default dict) -}}
    {{- $localDefaults := (include "arkcase.tools.get" (dict "ctx" $ctx "name" ".Values.persistence.defaults") | fromYaml | default dict) -}}

    {{- /* Overlay localDefaults on top of globalDefaults */ -}}
    {{- $defaults := mergeOverwrite $globalDefaults $localDefaults -}}
    {{- $defaultSize := (include "arkcase.tools.get" (dict "ctx" $defaults "name" "size") | default "1Gi") -}}
    {{- $defaultReclaimPolicy := (include "arkcase.tools.get" (dict "ctx" $defaults "name" "persistentVolumeReclaimPolicy") | default "Retain") -}}
    {{- $defaultStorageClassName := (include "arkcase.tools.get" (dict "ctx" $defaults "name" "storageClassName") | default "manual") -}}
    {{- $defaultAccessModes := (include "arkcase.tools.get" (dict "ctx" $defaults "name" "accessModes")) -}}
    {{- if not $defaultAccessModes -}}
      {{- $defaultAccessModes = (list "ReadWriteOnce") -}}
    {{- end -}}

    {{- $claimName := (default "" ($volumeData.claim).name) -}}
    {{- $claimSpec := (default dict ($volumeData.claim).spec) -}}
    {{- $volumeSpec := (default dict $volumeData.spec) -}}

    {{- $storageClassName := $defaultStorageClassName -}}
    {{- $accessModes := $defaultAccessModes -}}
    {{- $storageSize := $defaultSize -}}

    {{- if not $claimName -}}
    {{- if not $claimSpec -}}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {{ $volumeObjectName | quote }}
  namespace: {{ $ctx.Release.Namespace | quote }}
  labels: {{- include "arkcase.labels" $ctx | nindent 4 }}
    {{- with $ctx.Values.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $volumeData.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    arkcase/persistentVolume: {{ $volumeObjectName | quote }}
  annotations:
    {{- with $ctx.Values.annotations  }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $volumeData.annotations  }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
{{- if ($volumeSpec) }}
  {{- if $volumeSpec.accessModes -}}
    {{- $accessModes = $volumeSpec.accessModes -}}
  {{- end -}}
  {{- if ($volumeSpec.capacity).storage -}}
    {{- $storageSize = $volumeSpec.capacity.storage -}}
  {{- end -}}
  {{- if $volumeSpec.storageClassName -}}
    {{- $storageClassName = $volumeSpec.storageClassName -}}
  {{- end -}}
  {{- toYaml $volumeSpec | nindent 2 -}}
{{- else }}
  {{- /* Use "local-storage" when we've figured out the folder creation thing */ -}}
  {{- $storageClassName = "manual" }}
  storageClassName: {{ $storageClassName | quote }}
  persistentVolumeReclaimPolicy: {{ $defaultReclaimPolicy | quote }}
  accessModes: {{- toYaml $accessModes | nindent 4 }}
  capacity:
    storage: {{ $storageSize | quote }}
  {{- if (eq "local-storage" $storageClassName) }}
  # Use "local:" when using "local-storage" as the storage class
  local:
  {{- else }}
  # Use "hostPath:" when using "manual" as the storage class
  hostPath:
  {{- end }}
    {{- $localPath := $volumeData.localPath -}}
    {{- if not $localPath -}}
      {{- $localPath = coalesce (($ctx.Values.global).persistence).localPath ($ctx.Values.persistence).localPath $rootPath -}}
      {{- if $partname -}}
        {{- $volumeName = (printf "%s-%s" $partname $volumeName) -}}
      {{- end -}}
      {{- $localPath = (printf "%s/%s/%s" $localPath (include "arkcase.subsystem.name" $ctx) $volumeName) -}}
    {{- end }}
    path: {{ $localPath | quote }}
    type: DirectoryOrCreate
  {{- if (eq "local-storage" $storageClassName) }}
  # Node affinity is required when using "local-storage" as the storage class
  nodeAffinity:
    # TODO: Could eventually match kubernetes.io/hostname=$(hostname) ... must use kustomize or somesuch
    # TODO: This should probably be revised ... should work for now
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/os
              operator: In
              values:
                - linux
  {{- end }}
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: {{ $objectName | quote }}
    namespace: {{ $ctx.Release.Namespace | quote }}
{{- end }}

    {{- end }}

---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: {{ $objectName | quote }}
  namespace: {{ $ctx.Release.Namespace | quote }}
  labels: {{- include "arkcase.labels" $ctx | nindent 4 }}
    {{- with $ctx.Values.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $volumeData.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    arkcase/persistentVolumeClaim: {{ $objectName | quote }}
  annotations:
    {{- with $ctx.Values.annotations  }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $volumeData.annotations  }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
{{- if ($claimSpec) -}}
  {{- $claimSpec | toYaml | nindent 2 }}
{{- else }}
  volumeName: {{ $volumeObjectName | quote }}
  selector:
    matchLabels:
      arkcase/persistentVolume: {{ $volumeObjectName | quote }}
  storageClassName: {{ $storageClassName | quote }}
  accessModes: {{- toYaml $accessModes | nindent 4 }}
  resources:
    requests:
      storage: {{ $storageSize | quote }}
{{- end }}
    {{- end -}}

  {{- end -}}

{{- end -}}
