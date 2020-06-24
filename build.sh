echo $KEY_JKS | base64 --decode > key.jks && flutter build apk --release
