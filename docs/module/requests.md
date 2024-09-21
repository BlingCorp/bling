# Requests Module <!-- {docsify-ignore} -->

The `requests` module provides an interface for making asynchronous HTTP requests in AwesomeWM using the `lgi` bindings for `Soup`, `Gio`, and `GLib`.
It supports common HTTP methods like `GET`, `POST`, `PUT`, and more.

## Methods

### `requests.request(method, args, callback)`

#### Parameters:

- **method**: A string representing the HTTP method (`"GET"`, `"POST"`, etc.).
- **args**: A table or string. The table can include:
  - **url**: The request URL (string).
  - **params**: Query parameters (table).
  - **headers**: HTTP headers (table).
  - **body**: The request body (`GLib.Bytes` or string).
- **callback**: A function to handle the `Response` object.

#### Example:

```lua
requests.request("GET", { url = "https://api.example.com" }, function(response)
    print(response.status_code, response.text)
end)
```

---

### `requests.get(args, callback)`

#### Description:

A shorthand for making `GET` requests.

#### Parameters:

- **args**: Similar to `requests.request` but defaults to `GET` method.
- **callback**: Function called with a `Response` object.

#### Example:

```lua
requests.get({ url = "https://api.example.com" }, function(response)
    print(response.status_code, response.text)
end)
```

---

### `requests.post(args, callback)`

#### Description:

A shorthand for making `POST` requests.

#### Parameters:

- **args**: Similar to `requests.request` but defaults to `POST` method.
- **callback**: Function called with a `Response` object.

#### Example:

```lua
requests.post({
    url = "https://api.example.com",
    headers = { Authorization = "Bearer token" },
    body = '{"key": "value"}'
}, function(response)
    print(response.status_code, response.text)
end)
```

---

## Response Object

The `Response` object encapsulates the result of a request.

### Fields:

- **url**: The final URL after redirections.
- **status_code**: The HTTP status code (number).
- **ok**: A boolean indicating if the request was successful.
- **reason_phrase**: A string with the status reason.
- **text**: The response body as a string.
- **bytes**: The response body as `GLib.Bytes`.

### Example Usage:

```lua
print(response.url)  -- "https://api.example.com"
print(response.status_code)  -- 200
print(response.ok)  -- true
print(response.text)  -- Response body as string
```
