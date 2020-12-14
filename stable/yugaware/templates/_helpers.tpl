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
Implements customization for the registry for component images.

The preference is to use the image.commonRegistry field first if it is set.
Otherwise the local registry override for each image is used if set, for ex: image.postgres.registry

In both cases, the image name and tag can be customized by using the overrides for each image, for ex: image.postgres.name
*/}}
{{- define "full_image" -}}
  {{- $specific_registry := (get (get .root.Values.image .containerName) "registry") -}}
  {{- if not (empty .root.Values.image.commonRegistry) -}}
    {{- $specific_registry = .root.Values.image.commonRegistry -}}
  {{- end -}}
 {{- if not (empty $specific_registry) -}}
    {{- $specific_registry = printf "%s/" $specific_registry -}}
  {{- end -}}
  {{- $specific_name := (toString (get (get .root.Values.image .containerName) "name")) -}}
  {{- $specific_tag := (toString (get (get .root.Values.image .containerName) "tag")) -}}
  {{- printf "%s%s:%s" $specific_registry $specific_name $specific_tag  -}}
{{- end -}}

{{/*
Implements customization for the registry for the yugaware docker image.

The preference is to use the image.commonRegistry field first if it is set.
Otherwise the image.repository field is used.

In both cases, image.tag can be used to customize the tag of the yugaware image.
*/}}
{{- define "full_yugaware_image" -}}
  {{- $specific_registry := .Values.image.repository -}}
  {{- if not (empty .Values.image.commonRegistry) -}}
    {{- $specific_registry = printf "%s/%s" .Values.image.commonRegistry "yugabyte/yugaware" -}}
  {{- end -}}
  {{- $specific_tag := (toString .Values.image.tag) -}}
  {{- printf "%s:%s" $specific_registry $specific_tag  -}}
{{- end -}}
