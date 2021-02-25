# Configuration

## Introduction

The ownCloud iOS SDK provides a flexible mechanism for configuration that allows

- classes to provide default values
- injection of settings from managed configuration (MDM)

# Managed configuration

## Keys

The key names in the managed configuration dictionary are built from the section ID and the setting name, i.e. a Section ID of `connection` and a setting name of `endpoint-user` results in the key name  `connection.endpoint-user` for use in managed configuration dictionaries. 

## Available options

The file located at `doc/CONFIGURATION.json` provides a machine-readable list of available settings. For the `ios-sdk` repository, this includes only settings implemented in the SDK. For the full list of settings available for configuration, please see [`docs/modules/ROOT/pages/ios_mdm_tables.adoc`](https://github.com/owncloud/ios-app/blob/master/docs/modules/ROOT/pages/ios_mdm_tables.adoc) in the `ios-app` repository.

# Compile time configuration

## Preprocessor Macros

The inclusion and exclusion of some features can be controlled at compile time by adding or removing preprocessor macros:

### Support for `UIWebView`-based authentication sessions

By default, support for `UIWebView`-based authentication sessions is not included. If it is needed (f.ex. for MobileIron setups, where `ASWebAuthenticationSession` is not supported), it needs to be configured by adding

```
OC_FEATURE_AVAILABLE_UIWEBVIEW_BROWSER_SESSION=1
```

to the preprocessor flags of the Xcode project of the ownCloud SDK.

⚠️ Please note that - as of the time of writing - new apps with `UIWebView` are no longer allowed in the App Store, and updates to existing apps will no longer be allowed to use `UIWebView` come December 2020.
