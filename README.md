# My ejabberd HTTP based authentication module

## Overview

The purpose of this module is to connect with an external REST API and delegate the authentication operations to it whenever possible. The component must implement the API described in one of the next sections for authentication to work out of the box.

Thanks to ejabberd design, the user base does not have to be local and
this approach allows you to avoid user base duplication, without
having to grant access to your main backend database.

The module can be especially useful for users maintaining their own,
central user database, which is shared with other services. It fits
perfectly when client application uses custom authentication token and
ejabberd has to validate it externally.

## Installation
ejabberdctl module_install ejabberd_auth_my

## Configuration

### How to enable

The simplest way is to replace default `auth_method` option in
`ejabberd.yml` with `auth_method: my` and setup certain
configuration options.

### Configuration options

`ejabberd_auth_my` requires some parameters to function
properly. The following options should be set in `my_auth_opts` in
`ejabberd.yml`:

* `host` (mandatory, `string`) - consists of protocol, hostname (or IP) and port (optional). Examples:
  * `host: "http://localhost:8080"`
  * `host: "https://services.my.com"`
* `connection_pool_size` (optional, `integer`, default: 10) - the
  number of connections open to auth service
* `connection_opts` (optional, default: `[]`) - extra options (http://erlang.org/doc/man/gen_tcp.html#type-connect_option)
* `path_prefix` (optional, default: `"/"`) - a path prefix to be
  inserted between `host` and method name; must be terminated with `/`. Examples:
  * `path_prefix: "/api/"`

We also need to disable certain password verification mechanisms using the
following options with `disable_sasl_mechanism` in `ejabberd.yml`:
```yaml
disable_sasl_mechanisms:
  - "digest-md5"
  - "scram-sha-1"
```

Example of complete configuration:
```
auth_method: my
my_auth_opts:
  host: "https://services.my.com"
  connection_pool_size: 10
  connection_opts: []
  path_prefix: "/api/"

disable_sasl_mechanisms:
  - "digest-md5"
  - "scram-sha-1"
```
