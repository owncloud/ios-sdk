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
		- default: `ocs/v1.php/cloud/capabilities`
	- `endpoint-user`: Endpoint to use for retrieving information on logged in user
		- type: string
		- default: `ocs/v1.php/cloud/user`
	- `endpoint-webdav`: Endpoint to use for WebDAV
		- type: string
		- default: `remote.php/dav/files`
	- `endpoint-status`: Endpoint to retrieve basic status information and detect an ownCloud installation
		- type: string
		- default: `status.php`
	- `connection-insert-x-request-id`: Send a unique, random UUID in the `X-Request_ID` HTTP header with every request to enable server-side tracing ([Details](https://github.com/owncloud/ios-sdk/issues/1))
		- type: boolean
		- default: `true`
	- `connection-preferred-authentication-methods`: Array of authentication methods in order of preference (most prefered first).
		- type: array
		- default: `["com.owncloud.oauth2", "com.owncloud.basicauth"]`
	- `connection-allowed-authentication-methods`: Array of allowed authentication methods. Nil/Missing for no restrictions.
		- type: array
		- default: `nil`
	- `connection-strict-bookmark-certificate-enforcement`: If `true`:  require the certificate stored in the connection's bookmark if the connection's state is not disconnected. If `false`: accept all validating certificates and certificates approved by the user.
		- type: boolean
		- default: `true`

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
