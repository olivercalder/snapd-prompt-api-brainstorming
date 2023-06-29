# snapd-prompt-api-brainstorming

Exploring possible designs for a snapd prompting API.

This is meant to be an extension of the existing [snapd REST API](https://snapcraft.io/docs/snapd-rest-api) to enable apparmor prompting support in snapd.
In particular, this API allows prompt UI clients to receive and reply to prompt requests, and allows permission control panel applications to view, add, modify, and delete access rules.

*Note for Canonicalers working on Apparmor Prompting:* For an up-to-date description of this API and the broader Apparmor Prompting system, please see [SD121 - Apparmor Prompting](https://docs.google.com/document/d/1tBnefdukP69EUJOlH8bgD2hrvZCYoE8-1ZlqRRYlOqc) snapd spec.

### How to Use

To view and interact with the API, run
```
./sanitize_openapi.sh
```
and copy the output into [https://editor-next.swagger.io/](https://editor-next.swagger.io/).

## Design Goals

The API has two primary goals:

1. Allow prompt UI clients to receive and reply to prompt requests
2. Allow access rules to be retrieved, added, modified, or deleted by permission control panel applications

These correspond to two related but distinct concepts:

1. *Prompt requests*: used in communication between snapd and a prompt UI client, which are discarded once a reply is received
2. *Access rules*: used internally and in communication between snapd and a control center application, and may be added, modified, or deleted over time

When a prompt UI client replies to a prompt request, that reply may result in the creation of a new access rule which is then used to handle future requests.

Additionally, access rules can be [added directly](#post-v2access-controlrules) without there being a previous prompt request, and access rules can be [modified](#post-v2access-controlrulesid) or [deleted](#delete-v2access-controlrulesid) manually as well.
This allows an application like GNOME control center to manage access rules.

Thus, there is a relationship, but not a direct mapping, between prompt requests and access rules.
Both concepts use unique IDs to identify requests and rules, respectively, but those IDs are distinct between the two: an ID is used to identify prompt requests to the prompt UI client, and a new ID is assigned to an access rule by snapd if/when a corresponding rule is added to the database.

### Note on users and UIDs

Snapd is given the subject UID of any access request it receives from the kernel/apparmor, and it can identify the UID of any client connecting to an endpoint.
Thus, for all endpoints, snapd only works with the prompt requests or access rules corresponding to the UID of the connected client.

