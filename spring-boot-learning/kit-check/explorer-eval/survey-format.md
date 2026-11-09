## The readers' fact sheet

Each reader surveys one service folder and returns only a fact sheet. The main session merges the sheets into
`docs/explorer/survey.json`:

```json
{
  "services": [
    {
      "name": "checkoutservice",
      "language": "Go",
      "entryPoints": [{ "name": "CheckoutService.PlaceOrder", "ref": "src/checkoutservice/main.go:226" }],
      "calls": [{ "to": "paymentservice", "how": "gRPC", "ref": "src/checkoutservice/main.go:390" }],
      "stores": [{ "name": "Redis", "ref": "src/cartservice/src/cartstore/RedisCartStore.cs:40" }],
      "unsure": ["anything it couldn't trace, one line each"]
    }
  ]
}
```

| Field | What goes in it |
|---|---|
| `name` | the service, by the name it's deployed under |
| `entryPoints` | what something outside the service can call: a gRPC method as `Service.Method`, an HTTP route as `METHOD /path` |
| `calls` | each other service it talks to over the network, by its deployed name, and how (gRPC, HTTP, a queue) |
| `stores` | each database or cache it reads or writes |
| `ref` | the line where it happens, as `path:line` from the repository root |
| `unsure` | whatever couldn't be traced to a line |

**Rules for readers:** report only what the code shows, never a guess from a name. Every item cites its line; an item
without a line goes in `unsure` instead. Use read-only commands only.
