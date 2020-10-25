Examples of expressions:
- `bookmarkCertificate == serverCertificate`: the whole certificate needs to be identical to the one stored in the bookmark during setup.
- `bookmarkCertificate.publicKeyData == serverCertificate.publicKeyData`:  the public key of the received certificate needs to be identical to the public key stored in the bookmark during setup.
- `serverCertificate.passedValidationOrIsUserAccepted == true`: any certificate is accepted as long as it has passed validation by the OS or was accepted by the user.
- `serverCertificate.commonName == "demo.owncloud.org"`: the common name of the certificate must be "demo.owncloud.org".
- `serverCertificate.rootCertificate.commonName == "DST Root CA X3"`: the common name of the root certificate must be "DST Root CA X3".
- `serverCertificate.parentCertificate.commonName == "Let's Encrypt Authority X3"`: the common name of the parent certificate must be "Let's Encrypt Authority X3".
- `serverCertificate.publicKeyData.sha256Hash.asFingerPrintString == "2A 00 98 90 BD … F7"`: the SHA-256 fingerprint of the public key of the server certificate needs to match the provided value.
