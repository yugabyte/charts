{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "yugaware.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "yugaware.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "yugaware.chart" -}}
{{- printf "%s" .Chart.Name | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Validate Nginx SSL protocols
*/}}
{{- define "validate_nginx_ssl_protocols" -}}
  {{- $sslProtocolsRegex := `^((TLSv(1|1\.[1-3]))(?: ){0,1}){1,4}$` -}}
  {{- if not (regexMatch $sslProtocolsRegex .Values.tls.sslProtocols) -}}
    {{- fail (cat "Please specify valid tls.sslProtocols, must match regex:" $sslProtocolsRegex) -}}
  {{- else -}}
    {{- .Values.tls.sslProtocols -}}
  {{- end -}}
{{- end -}}
