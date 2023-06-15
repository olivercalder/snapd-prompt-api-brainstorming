# snapd-prompt-api-brainstorming

Exploring possible designs for a snapd prompting API.

This is meant to be an extension of the existing [snapd REST API](https://snapcraft.io/docs/snapd-rest-api) to enable apparmor prompting support in snapd.
In particular, this API allows prompt UI clients to receive and respond to resource access requests, and allows permission control panel applications to view, add, modify, and delete rules about resource access.

### How to Use

To view and interact with the API, run
```
./sanitize_openapi.sh
```
and copy the output into [https://editor-next.swagger.io/](https://editor-next.swagger.io/)

The following description is designed to be a condensed summary of the API.
To explore the complete API, it is recommended to use [https://editor-next.swagger.io/](https://editor-next.swagger.io/) as described above, or an equivalent tool.

## Design Goals

The API has two primary goals:

1. Allow prompt UI clients to receive and respond to resource access requests
2. Allow resource access rules to be retrieved, added, modified, or deleted by permission control panel applications

## Endpoints

- [`/v2/prompting/requests`](#v2promptingrequests)
- [`/v2/prompting/requests/{id}`](#v2promptingrequestsid)
- [`/v2/prompting/decisions`](#v2promptingdecisions)
- [`/v2/prompting/decisions/{id}`](#v2promptingdecisionsid)

### `/v2/prompting/requests`

Actions related resource access requests.

This endpoint is designed to be used by prompt UI clients whose responsibility it is to receive and respond to resource access requests.

#### `GET /v2/prompting/requests`

Retrieve all outstanding requests.

##### Parameters

- `follow`: Open a long-lived connection using ["json-seq"](https://docs.google.com/document/d/1vTq0iGVypVEeZhm8y1oTHLTRx8sOXDLOJjU-t89FhTc)

##### Returns

List of [`request`](#request)s.

### `/v2/prompting/requests/{id}`

Actions for a particular resource access request.

#### `GET /v2/prompting/requests/{id}`

Retrieve the resource access request with the given ID.

##### Parameters

- `id`: The unique identifier of the request

##### Returns

The corresponding [`request`](#request) information.

#### `POST /v2/prompting/requests/{id}`

Respond to the resource access request with the given ID.

##### Parameters

- `id`: The unique identifier of the request
- `response`: The [`response`](#response) details from the UI client for the given request

##### Returns

The [`changed-decisions`](#changed-decisions) which resulted from submitting the response --- see there for more details.

### `/v2/prompting/decisions`

Actions regarding stored decisions.

This endpoint is designed to be used primarily by "control panel" applications which can configure permissions directly without being prompted.

#### `GET /v2/prompting/decisions`

Get existing resource access decisions.

##### Parameters

- `follow`: Open a long-lived connection using ["json-seq"](https://docs.google.com/document/d/1vTq0iGVypVEeZhm8y1oTHLTRx8sOXDLOJjU-t89FhTc)
- `snap`: Only get stored decisions associated with the given snap
- `app`: Only get stored decisions associated with the given app (requires the `snap` parameter as well)

##### Returns

List of [`decision`](#decision) entries.

#### `POST /v2/prompting/decisions`

Create a new resource access decision.

##### Parameters

- `decision`: The new [`decision`](#decision) to add (omit `id` and `timestamp`)

##### Returns

The [`changed-decisions`](#changed-decisions) which resulted from adding the new decision --- see there for more details.

#### `DELETE /v2/prompting/decisions`

Delete stored resource access decisions.

##### Parameters

- `snap`: Only delete stored decisions associated with the given snap
- `app`: Only delete stored decisions associated with the given app (requires the `snap` parameter as well)

##### Returns

List of [`decision`](#decision) entries which were deleted.

### `/v2/prompting/decisions/{id}`

Actions associated with a particular saved resource access decision.

#### `GET /v2/prompting/decisions/{id}`

Get the stored decision with the given ID.

##### Parameters

- `id`: The unique identifier of the stored decision

##### Returns

The [`decision`](#decision) information associated with the given ID.

#### `POST /v2/prompting/decisions/{id}`

Modify the stored decision with the given ID.

##### Parameters

- `id`: The unique identifier of the stored decision
- `response`: The updated [`response`](#response) information to store with the decision

##### Returns

The [`changed-decisions`](#changed-decisions) which resulted from modifying the decision --- see there for more details.

#### `DELETE /v2/prompting/decisions/{id}`

Delete the stored decision with the given ID.

##### Parameters

- `id`: The unique identifier of the stored decision

##### Returns

The [`decision`](#decision) which was deleted.

## Notable Schemas

### `request`

| Field | Required/Optional | Description | Options |
| -- | -- | ---------------- | ---- |
| `id` | Required | The unique identifier of the request | |
| `snap` | Required | The name of the snap which triggered the request | |
| `app` | Required | The name of the app which triggered the request | |
| `path` | Required | The path of the resource being requested | |
| `resource-type` | Required | The device type or path type of the resource being requested | `file`, `directory`, `camera`, `microphone`, etc. |
| `permissions` | Required | The permissions being requested | List of [`permission`](#permission) |


### `response`

| Field | Required/Optional | Description | Options |
| -- | -- | ---------------- | ---- |
| `allow` | Required | Whether access is allowed or denied | `true`, `false`
| `duration` | Required | How long the response decision should be valid | `single`, `session`, `always`, `timeframe` |
| `permissions` | Optional | A list of operations for which a decision applies --- the permissions in the original request are assumed | List of [`permission`](#permission) |
| `path-access` | Optional | The paths for which to apply the decision | `file`, `directory`, `subdirectories` |

### `decision`

| Field | Required/Optional | Description | Options |
| -- | -- | ---------------- | ---- |
| `id` | Required | The unique identifier of the decision | |
| `timestamp` | Required | The timestamp at which the decision was created or last modified | |
| `snap` | Required | The name of the snap associated with the decision | |
| `app` | Required | The name of the app associated with the decision | |
| `path` | Required | The path of the resource associated with the decision | |
| `resource-type` | Required | The device type or path type of the resource being requested | `file`, `directory`, `camera`, `microphone`, etc. |
| `allow` | Required | Whether access is allowed or denied | `true`, `false` |
| `duration` | Required | How long the decision should be valid | `single`, `session`, `always`, `timeframe` |
| `permissions` | Required | The list of operations for which the decision applies | List of [`permission`](#permission) |
| `path-access` | Required | The paths for which to apply the decision | `file`, `directory`, `subdirectories` |

### `changed-decisions`

When responding to a request or attempting to add a new decision directly, the resulting new decision might be implied by previous decisions, in which case it will not be added and the `new` field will be empty.

If a new decision is added, previous decisions may be "pruned" by removing particular operations which have been overruled by the new decision.
Those decisions will appear in the `modified` list.

If all operations are removed from an existing decision, that decision is deleted by removing it from the decisions index (that is, it will no longer be included in responses from the `/v2/prompting/decisions` endpoint).
Any such decision will appear in the `deleted` list.

| Field | Required/Optional | Description | Options |
| -- | -- | ---------------- | ---- |
| `new` | Optional | New decisions which were added as a result of some change | List of [`decision`](#decision) |
| `modified` | Optional | Decisions which were modified as a result of some change | List of [`decision`](#decision) |
| `deleted` | Optional | Decisions which were deleted as a result of some change | List of [`decision`](#decision) |

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
