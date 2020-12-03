{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "yugabyte.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 43 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
The components in this chart create additional resources that expand the longest created name strings.
The longest name that gets created of 20 characters, so truncation should be 63-20=43.
*/}}
{{- define "yugabyte.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 43 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 43 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 43 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Generate common labels */}}
{{- define "yugabyte.labels" }}
heritage: {{ .Values.helm2Legacy | ternary "Tiller" (.Release.Service | quote) }}
release: {{ .Release.Name | quote }}
chart: {{ .Values.oldNamingStyle | ternary .Chart.Name (include "yugabyte.chart" .) | quote }}
component: {{ .Values.Component | quote }}
{{- if .Values.commonLabels}}
{{ toYaml .Values.commonLabels }}
{{- end }}
{{- end }}

{{/* Generate app label */}}
{{- define "yugabyte.applabel" }}
{{- if .root.Values.oldNamingStyle }}
app: "{{ .label }}"
{{- else }}
app.kubernetes.io/name: "{{ .label }}"
{{- end }}
{{- end }}

{{/* Generate app selector */}}
{{- define "yugabyte.appselector" }}
{{- if .root.Values.oldNamingStyle }}
app: "{{ .label }}"
{{- else }}
app.kubernetes.io/name: "{{ .label }}"
release: {{ .root.Release.Name | quote }}
{{- end }}
{{- end }}

{{/* Create Volume name */}}
{{- define "yugabyte.volume_name" -}}
{{- printf "%s-datadir" (include "yugabyte.fullname" .) -}}
{{- end -}}

{{/*
Derive the memory hard limit for each POD based on the memory limit.
Since the memory is represented in <x>GBi, we use this function to convert that into bytes.
Multiplied by 870 since 0.85 * 1024 ~ 870 (floating calculations not supported)
*/}}
{{- define "yugabyte.memory_hard_limit" -}}
{{- printf "%d" .limits.memory | regexFind "\\d+" | mul 1024 | mul 1024 | mul 870 }}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "yugabyte.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
  Get YugaByte fs data directories
*/}}
{{- define "yugabyte.fs_data_dirs" -}}
{{range $index := until (int (.count))}}{{if ne $index 0}},{{end}}/mnt/disk{{ $index }}{{end}}
{{- end -}}

{{/*
  Get YugaByte master addresses
*/}}
{{- define "yugabyte.master_addresses" -}}
{{- $master_replicas := .Values.replicas.master | int -}}
{{- $domain_name := .Values.domainName -}}
{{- $prefix := (include "yugabyte.fullname" .)  -}}
  {{- range .Values.Services }}
    {{- if eq .name "yb-masters" }}
      {{- if $.Values.oldNamingStyle }}
      {{range $index := until $master_replicas }}{{if ne $index 0}},{{end}}yb-master-{{ $index }}.yb-masters.$(NAMESPACE).svc.{{ $domain_name }}:7100{{end}}
      {{- else }}
      {{range $index := until $master_replicas }}{{if ne $index 0}},{{end}}{{- $prefix }}-yb-master-{{ $index }}.{{- $prefix }}-yb-masters.$(NAMESPACE).svc.{{ $domain_name }}:7100{{end}}
      {{- end }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Compute the maximum number of unavailable pods based on the number of master replicas
*/}}
{{- define "yugabyte.max_unavailable_for_quorum" -}}
{{- $master_replicas := .Values.replicas.master | int | mul 100 -}}
{{- $master_replicas := 100 | div (100 | sub (2 | div ($master_replicas | add 100))) -}}
{{- printf "%d" $master_replicas -}}
{{- end -}}
