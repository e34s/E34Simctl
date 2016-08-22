# E34Simctl

- Start the WebServer (default port is 9898)
- To launch a simulator:

```
POST http://localhost:9898/simulator/launch
HEADERS:
      Content-Type: application/json
BODY:
{
      "simulator": "iPhone 6"
}
```
This will allocate a new simulator and launch it, together with WebDriverAgent.
When the requests comes back (it might take a while), this should be the body

```
{
  "status": 0,
  "value": {
    "sessionId": "CCE0CE37-0539-49BD-8054-F245DFE96FD7",
    "capabilities": {
      "device": "iphone",
      "browserName": null,
      "CFBundleIdentifier": null,
      "sdkVersion": "9.3"
    }
  },
  "webdriverUrl": "http://localhost:27273/session/CCE0CE37-0539-49BD-8054-F245DFE96FD7",
  "sessionId": "CCE0CE37-0539-49BD-8054-F245DFE96FD7",
  "inspectorUrl": "http://localhost:27273/inspector"
}
```

Test runner code will be injected in a system app (Safari); the actual test app is (for now) TableSearch from Apple.s

(!) Note: Currently allocating a new simulator every time, so careful or you might end up like this:
![oops](http://i.imgur.com/qwUUjVp.png)

`
