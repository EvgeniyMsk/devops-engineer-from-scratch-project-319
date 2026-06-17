.PHONY: secret

secret_file:
	SA_ID=$$(yc iam service-account get eso-service-account --format json | jq -r .id) && \
	LOCKBOX_ID=$$(terraform -chdir=../terraform output -raw lockbox_secret_id) && \
	yc lockbox secret add-access-binding \
		--id "$$LOCKBOX_ID" \
		--role lockbox.payloadViewer \
		--service-account-id "$$SA_ID" && \
	yc iam key create \
		--service-account-name eso-service-account \
		--output authorized-key.json

secret:
	kubectl create secret generic yc-auth \
  		--namespace hexlet-project \
  		--from-file=authorized-key=authorized-key.json \
  		--dry-run=client -o yaml | kubectl apply -f -