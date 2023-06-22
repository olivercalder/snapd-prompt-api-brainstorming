# snapd-prompt-api-brainstorming

Exploring possible designs for a snapd prompting API.

This is meant to be an extension of the existing [snapd REST API](https://snapcraft.io/docs/snapd-rest-api) to enable apparmor prompting support in snapd.
In particular, this API allows prompt UI clients to receive and reply to prompt requests, and allows permission control panel applications to view, add, modify, and delete access decisions.

### How to Use

To view and interact with the API, run
```
./sanitize_openapi.sh
```
and copy the output into [https://editor-next.swagger.io/](https://editor-next.swagger.io/).

The following description is designed to be a condensed summary of the API.
To explore the complete API, it is recommended to use [https://editor-next.swagger.io/](https://editor-next.swagger.io/) as described above, or an equivalent tool.

## Design Goals

The API has two primary goals:

1. Allow prompt UI clients to receive and reply to prompt requests
2. Allow access decisions to be retrieved, added, modified, or deleted by permission control panel applications

These correspond to two related but distinct concepts:

1. *Prompt requests*: used in communication between snapd and a prompt UI client, which are discarded once a reply is received
2. *Access decisions*: used internally and in communication between snapd and a control center application, and may be added, modified, or deleted over time

When a prompt UI client replies to a prompt request, that reply may result in the creation of a new access decision which is then used to handle future requests.
If the choices specified in the reply are already implied by existing access decisions, then no new access decision is created (this is referred to as *consolidation*).
If a new access decision is created, any existing access decisions which are *more specific* than the new rule (that is, for a given permission, the new decision implies the existing decision) will be *pruned*: any permissions (read, write, execute, etc.) common to both the new and existing decision will be removed from the latter; if the final permission is removed from an existing decision, that decision is deleted.

Additionally, access decisions can be [added directly](#post-v2promptingdecisions) without there being a previous prompt request, and access decisions can be [modified](#post-v2promptingdecisionsid) or [deleted](#delete-v2promptingdecisionsid) manually as well.
This allows an application like GNOME control center to manage access decisions.

Thus, there is a relationship, but not a direct mapping, between prompt requests and access decisions.
Both concepts use unique IDs to identify requests and decisions, respectively, but those IDs are distinct between the two: an ID is used to identify prompt requests to the prompt UI client, and a new ID is assigned to an access decision by snapd if/when a corresponding decision is added to the database.

### Note on users and UIDs

Snapd is given the subject UID of any access request it receives from the kernel/apparmor, and it can identify the UID of any client connecting to an endpoint.
Thus, for all endpoints, snapd only works with the prompt requests or access decisions corresponding to the UID of the connected client.

## Endpoints

- [`/v2/prompting/requests`](#v2promptingrequests)
- [`/v2/prompting/requests/{id}`](#v2promptingrequestsid)
- [`/v2/prompting/decisions`](#v2promptingdecisions)
- [`/v2/prompting/decisions/{id}`](#v2promptingdecisionsid)

### `/v2/prompting/requests`

Actions related prompt requests.

This endpoint is designed to be used by prompt UI clients whose responsibility it is to receive and reply to access requests from snapd (which correspond to requests from the kernel to snapd).

#### `GET /v2/prompting/requests`

Retrieve all prompt requests for which a reply has not yet been received.

##### Parameters

- `follow`: Open a long-lived connection using ["json-seq"](https://docs.google.com/document/d/1vTq0iGVypVEeZhm8y1oTHLTRx8sOXDLOJjU-t89FhTc) so that whenever snapd creates a new prompt request, it is sent immediately along this open connection.

##### Request Body

n/a

##### Response Body

List of [`request`](#request) objects.

### `/v2/prompting/requests/{id}`

Actions for a particular resource prompt request.

#### `GET /v2/prompting/requests/{id}`

Retrieve the prompt request with the given ID.

##### Parameters

- `id`: The unique identifier of the prompt request.

##### Request Body

n/a

##### Response Body

The [`request`](#request) object corresponding to the given ID.

#### `POST /v2/prompting/requests/{id}`

Reply to the resource access request with the given ID.

##### Parameters

- `id`: The unique identifier of the prompt request.

##### Request Body

The [`reply`](#reply) object containing the answer from the UI client for the given request.

##### Response Body

The [`changed-decisions`](#changed-decisions) which resulted from submitting the response --- see there for more details.

### `/v2/prompting/decisions`

Actions regarding stored access decisions.

This endpoint is designed to be used primarily by "control panel" applications which can configure access permissions directly without being prompted.

#### `GET /v2/prompting/decisions`

Get existing access decisions.

##### Parameters

- `snap`: Only get stored access decisions associated with the given snap.
- `app`: Only get stored access decisions associated with the given app within the given snap.
  - The `app` parameter is ignored if the `snap` parameter is not also included.
- `follow`: Open a long-lived connection using ["json-seq"](https://docs.google.com/document/d/1vTq0iGVypVEeZhm8y1oTHLTRx8sOXDLOJjU-t89FhTc) so that whenever an access decision is added, modified, or deleted, it is sent immediately along this open connection.
  - The `follow` parameter is ignored if the `snap` parameter is not also included.

##### Request Body

n/a

##### Response Body

List of [`decision`](#decision) entries.

#### `POST /v2/prompting/decisions`

Create a new access decision.

##### Request Body

The new [`decision`](#decision) to add (technically `decision-contents`, which omits `id` and `timestamp`).

##### Response Body

The [`changed-decisions`](#changed-decisions) which resulted from adding the new decision --- see there for more details.

#### `DELETE /v2/prompting/decisions`

Delete stored access decisions.

##### Parameters

- `snap` (required): Only delete stored decisions associated with the given snap.
- `app`: Only delete stored decisions associated with the given app within the given snap.
- `confirm-delete`: A boolean parameter which must be included in the HTTP request in order to confirm that the caller wishes to remove multiple decisions at once.

##### Request Body

n/a

##### Response Body

List of [`decision`](#decision) entries which were deleted.

### `/v2/prompting/decisions/{id}`

Actions regarding the saved access decision with the given ID.

#### `GET /v2/prompting/decisions/{id}`

Get the access decision with the given ID.

##### Parameters

- `id`: The unique identifier of the stored access decision.

##### Request Body

n/a

##### Response Body

The [`decision`](#decision) information associated with the given ID.

#### `POST /v2/prompting/decisions/{id}`

Modify the stored decision with the given ID.

##### Parameters

- `id`: The unique identifier of the stored decision

##### Request Body

The updated [`reply`](#reply) information to replace that which was previously associated with the decision.

Since a `reply` object is used as the payload, the `allow` (allow/deny), `lifetime`, `permissions` (list of operations like `read`, `write`, etc.), and `path-scope` (file, directory, subdirectories) fields of the stored access decision can be modified.

##### Response Body

The [`changed-decisions`](#changed-decisions) which resulted from modifying the decision --- see there for more details.

#### `DELETE /v2/prompting/decisions/{id}`

Delete the stored access decision with the given ID.

##### Parameters

- `id`: The unique identifier of the stored decision.

##### Request Body

n/a

##### Response Body

The [`decision`](#decision) information which was deleted.

## Notable Schemas

### `request`

| Field | Required/Optional | Description | Options |
| -- | -- | ---------------- | ---- |
| `request-id` | Required | The unique identifier of the request | |
| `snap` | Required | The name of the snap which triggered the request | |
| `app` | Required | The name of the app which triggered the request | |
| `path` | Required | The path of the resource being requested | |
| `resource-type` | Required | The device type or path type of the resource being requested | `file`, `directory`, `camera`, `microphone`, etc. |
| `permissions` | Required | The permissions being requested | List of [`permission`](#permission) |

### `reply`

| Field | Required/Optional | Description | Options |
| -- | -- | ---------------- | ---- |
| `allow` | Required | Whether access is allowed or denied | `true`, `false` |
| `lifetime` | Required | How long the reply should be valid | `single`, `session`, `always`, `timeframe` |
| `permissions` | Optional | A list of operations for which the access applies --- the permissions in the original request are assumed | List of [`permission`](#permission) |
| `path-scope` | Optional | The paths for which the access applies | `file`, `directory`, `subdirectories` |

### `decision`

| Field | Required/Optional | Description | Options |
| -- | -- | ---------------- | ---- |
| `decision-id` | Required | The unique identifier of the decision | |
| `timestamp` | Required | The timestamp at which the decision was created or last modified | |
| `snap` | Required | The name of the snap associated with the decision | |
| `app` | Required | The name of the app associated with the decision | |
| `path` | Required | The path of the resource associated with the decision | |
| `resource-type` | Required | The device type or path type of the resource being requested | `file`, `directory`, `camera`, `microphone`, etc. |
| `allow` | Required | Whether access is allowed or denied | `true`, `false` |
| `lifetime` | Required | How long the decision should be valid | `single`, `session`, `always`, `timeframe` |
| `permissions` | Required | The list of operations for which the access decision applies | List of [`permission`](#permission) |
| `path-scope` | Required | The paths for which the access decision applies | `file`, `directory`, `subdirectories` |

### `changed-decisions`

When responding to a request or attempting to add a new decision directly, the resulting new decision might be implied by previous decisions, in which case it will not be added and the `new` field will be empty.

If a new decision is added, previous decisions may be *pruned* by removing particular operations which have been overruled by the new decision.
Those decisions will appear in the `modified` list.

If all operations are removed from an existing decision, that decision is deleted by removing it from the decisions index (that is, it will no longer be included in responses from the `/v2/prompting/decisions` endpoint).
Any such decision will appear in the `deleted` list.

| Field | Required/Optional | Description | Options |
| -- | -- | ---------------- | ---- |
| `new` | Optional | New access decisions which were added as a result of some change | List of [`decision`](#decision) |
| `modified` | Optional | Access decisions which were modified as a result of some change | List of [`decision`](#decision) |
| `deleted` | Optional | Access decisions which were deleted as a result of some change | List of [`decision`](#decision) |

### `permission`

The operations for which a particular request or decision applies.

- `execute`
- `write`
- `read`
- `append`
- `create`
- `delete`
- `open`
- `rename`
- `set-attribute`
- `get-attribute`
- `set-credential`
- `get-credential`
- `change-mode`
- `change-owner`
- `change-group`
- `lock`
- `execute-map`
- `link`
- `change-profile-on-exec`
- `change-profile`
