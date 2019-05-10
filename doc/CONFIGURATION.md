# Configuration

## Introduction

The ownCloud iOS SDK provides a flexible mechanism for configuration that allows

- classes to provide default values
- injection of settings from managed configuration (MDM)

This document provides an overview over the available sections and variables.

## Connection

- **Section ID**: `connection`

- **Variables**:
	- `endpoint-capabilities`: Endpoint to use for retrieving server capabilities
		- type: string
		- default: `ocs/v2.php/cloud/capabilities`
	- `endpoint-user`: Endpoint to use for retrieving information on logged in user
		- type: string
		- default: `ocs/v2.php/cloud/user`
	- `endpoint-webdav`: Endpoint to use for WebDAV
		- type: string
		- default: `remote.php/dav/files`
	- `endpoint-status`: Endpoint to retrieve basic status information and detect an ownCloud installation
		- type: string
		- default: `status.php`
	- `connection-preferred-authentication-methods`: Array of authentication methods in order of preference (most prefered first).
		- type: array
		- default: `["com.owncloud.oauth2", "com.owncloud.basicauth"]`
	- `connection-allowed-authentication-methods`: Array of allowed authentication methods. Nil/Missing for no restrictions.
		- type: array
		- default: `nil`
	- `connection-certificate-extended-validation-rule`: Rule that defines the criteria a certificate needs to meet for OCConnection to recognize it as valid for a bookmark.
		- type: string
		- default: `bookmarkCertificate == serverCertificate`
		- examples of expressions:
			- `bookmarkCertificate == serverCertificate`: the whole certificate needs to be identical to the one stored in the bookmark during setup.
			- `bookmarkCertificate.publicKeyData == serverCertificate.publicKeyData`:  the public key of the received certificate needs to be identical to the public key stored in the bookmark during setup.
			- `serverCertificate.passedValidationOrIsUserAccepted == true`: any certificate is accepted as long as it has passed validation by the OS or was accepted by the user.
			- `serverCertificate.commonName == "demo.owncloud.org"`: the common name of the certificate must be "demo.owncloud.org".
			- `serverCertificate.rootCertificate.commonName == "DST Root CA X3"`: the common name of the root certificate must be "DST Root CA X3".
			- `serverCertificate.parentCertificate.commonName == "Let's Encrypt Authority X3"`: the common name of the parent certificate must be "Let's Encrypt Authority X3".
			- `serverCertificate.publicKeyData.sha256Hash.asFingerPrintString == "2A 00 98 90 BD … F7"`: the SHA-256 fingerprint of the public key of the server certificate needs to match the provided value.
	- `connection-renewed-certificate-acceptance-rule`: Rule that defines the criteria that need to be met for OCConnection to accept a renewed certificate and update the bookmark's certificate automatically instead of prompting the user. Used when the extended validation rule fails. Set this to "never" if the user should always be prompted when a server's certificate changed.
		- type: string
		- default: `(bookmarkCertificate.publicKeyData == serverCertificate.publicKeyData) OR ((check.parentCertificatesHaveIdenticalPublicKeys == true) AND (serverCertificate.passedValidationOrIsUserAccepted == true))`
	- `connection-minimum-server-version`:  The minimum server version required.
		- type: string
		- default: `9.0`
	- `allow-background-url-sessions`: Allow the use of background URL sessions.
		- type: boolean
		- default: `true`
	- `allow-cellular`: Allow the use of cellular connections.
		- type: boolean
		- default: `true`
	- `plain-http-policy`: Policy regarding the use of plain (unencryped) HTTP URLs for creating bookmarks. A value of `warn` will create an issue (typically then presented to the user as a warning), but ultimately allow the creation of the bookmark. A value of `forbidden` will block the use of `http`-URLs for the creation of new bookmarks.
		- type: string
		- default: `warn`

## Core

- **Section ID**: `core`

- **Variables**:
	- `thumbnail-available-for-mime-type-prefixes`: Provide hints that thumbnails are available for items whose MIME-Type starts with any of the strings provided in this array. Providing an empty array turns off thumbnail loading. Providing `["*"]` turns on thumbnail loading for all items.
		- type: array
		- default: `["*"]`
	- `add-accept-language-header`: Add an `Accept-Language` HTTP header using the preferred languages set on the device.
		- type: bool
		- default: `true`
	- `override-reachability-signal`: Override the reachability signal, so the host is always considered reachable (`true`) or unreachable (`false`)
		- type: bool
		-default: -
	- `override-availability-signal`: Override the availability signal, so the host is considered to always be in maintenance mode (`true`) or never in maintenance mode (`false`) 
		- type: bool
		-default: -

## Logging

- **Section ID**: `log`

- **Variables**:
	- `log-level`: Log level. `0` for `debug`, `1` for `info`, `2` for `warning`, `3` for `error`, `4` for `off`,
		- type: number
		- default: `4` (`off`)
	- `log-privacy-mask`: Controls whether certain objects in log statements should be masked for privacy. 
		- type: boolean
		- default: `false`
	- `log-enabled-components`: List of enabled logging system components. 
		- type: array
		- default: `["writer.stderr", "writer.file", "option.log-requests-and-responses"]`
	- `log-synchronous`: Controls whether log messages should be written synchronously (which can impact performance) or asynchronously (which can loose messages in case of a crash). 
		- type: boolean
		- default: `true`
	- `log-only-tags`: If set, omits all log messages not tagged with tags in this array.
		- type: array
		- default: none
	- `log-omit-tags`: If set, omits all log messages tagged with tags in this array.
		- type: array
		- default: none
	- `log-only-matching`: If set, only logs messages containing at least one of the exact terms in this array.
		- type: array
		- default: none
	- `log-omit-matching`: If set, omits logs messages containing any of the exact terms in this array.
		- type: array
		- default: none
	- `log-blank-filtered-messages`: Controls whether filtered out messages should still be logged, but with the message replaced with `-`. 
		- type: boolean
		- default: `false`

## OAuth2

- **Section ID**: `authentication-oauth2`

- **Variables**:
	- `oa2-authorization-endpoint`: OAuth2 authorization endpoint
		- type: string
		- default: `index.php/apps/oauth2/authorize`
	- `oa2-token-endpoint`: OAuth2 token endpoint
		- type: string
		- default: `index.php/apps/oauth2/api/v1/token`
	- `oa2-redirect-uri`: OAuth2 Redirect URI
		- type: string
		- default: `oc://ios.owncloud.com`
	- `oa2-client-id`: OAuth2 Client ID
		- type: string
		- default: `mxd5OQDk6es5LzOzRvidJNfXLUZS2oN3oUFeXPP8LpPrhx3UroJFduGEYIBOxkY1`
	- `oa2-client-secret`: OAuth2 Client Secret
		- type: string
		- default: `KFeFWWEZO9TkisIQzR3fo7hfiMXlOpaqP8CFuTbSHzV1TUuGECglPxpiVKJfOXIx`

# Managed configuration

## Keys

The key names in the managed configuration dictionary are built from the section ID and the variable name, i.e. a Section ID of `connection` and a variable name of `endpoint-user` results in the key name  `connection.endpoint-user` for use in managed configuration dictionaries.
