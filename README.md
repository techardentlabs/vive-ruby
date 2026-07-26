# vive

Official Ruby client for the [Vive](https://app.getvive.ai) WhatsApp messaging API.

```bash
gem install vive
```

```ruby
require "vive"

vive = Vive::Client.new # reads VIVE_API_KEY
message = vive.send_text(to: "15551234567", text: "Your order shipped.")
```

- All ten message types: text, template, media, buttons, list, CTA, location, reaction
- No runtime dependencies beyond the standard library
- `Vive::Error` / `AuthError` / `RateLimitError` / `ValidationError`
- Automatic retry of `429` and `5xx` with backoff; never retries `4xx`
- Constant-time webhook signature verification

Full documentation: <https://app.getvive.ai/docs/>.
