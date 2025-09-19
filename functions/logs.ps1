param([string]\sendratingnotification='sendratingnotification',[int]\=100)
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="'"\sendratingnotification"'"' 
  --project  --limit \ --order=desc 
  --format 'table(timestamp, severity, jsonPayload.message, textPayload)'
