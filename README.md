# TapReply

**Double-tap the back of your iPhone. Get the right reply.**

TapReply is an iOS app that writes your replies for you. In any conversation, you double-tap the back of your iPhone: TapReply reads the conversation on your screen, writes a reply in the tone you choose, and copies it. You just paste and send.

Built for the **RevenueCat Shipaton 2026** (Next Gen Award) by Pierre Madi, a student at Audencia (Nantes, France).

- **Try it on TestFlight:** https://testflight.apple.com/join/nHXgMWuq
- **Privacy policy:** https://tapreply.vercel.app/privacy

---

## What it does

| Feature | How it works |
|---|---|
| **Reply in 2 taps** | iOS Back Tap (Settings › Accessibility › Touch › Back Tap) runs the TapReply shortcut: it takes a screenshot and calls the app's `Analyze` App Intent. The reply is copied to the clipboard and shown in a Live Activity (Dynamic Island) or a notification. |
| **Your draft, its words** | Type a rough idea in the message field ("cant tmrw.. friday??"). TapReply reads it from the screen and turns it into a clear, natural message that keeps your meaning. |
| **Tones** | Classic, Professional, Funny, Charmer, and **Fact Check**, which checks a claim on screen and answers TRUE / FALSE / NOTHING TO CHECK instead of replying. |
| **Custom tones** | Create your own tone in the Studio (name, mascot, color, instructions). 1 custom tone free, unlimited with Pro. |
| **3 shortcuts** | Assign a tone to Double Tap, Triple Tap and the Action Button. |
| **History** | Every reply is saved **on the iPhone only** (SwiftData), with favorites. |
| **Test tab** | A built-in fake conversation to try the gesture safely, and a chat to test each tone. |
| **iPad** | No Back Tap on iPad, so an "Analyze an existing screenshot" picker is shown instead. |
| **6 languages** | English, French, Spanish, German, Italian, Brazilian Portuguese (String Catalogs). |

## Monetization, powered by RevenueCat

| Offer | Details |
|---|---|
| **Free** | 10 free replies, granted once by the server as RevenueCat **Virtual Currency** (`RPLY`), plus 1 custom tone. |
| **TapReply Pro** | Monthly or annual auto-renewable subscription (entitlement `pro`), with a **3-day free trial** on the annual plan. Unlimited replies for personal use, 2 extra tone shortcuts, unlimited custom tones, exclusive app icons. |
| **50 replies pack** | Consumable in-app purchase that adds 50 `RPLY` credits. |

How it is wired:

- `PurchaseService.swift` uses the RevenueCat SDK (`purchases-ios` 5.x): offerings, purchases, restore, `customerInfoStream` for live entitlement updates, and the virtual currency balance.
- **Credits cannot be faked on the device.** The Edge Function checks the entitlement and the balance with the **RevenueCat REST API v2**, debits 1 `RPLY` **before** calling the AI, and refunds it automatically if the generation fails.
- The welcome credits are granted server-side, once per anonymous RevenueCat ID (`tapreply_claim_welcome`), and the claim is released if RevenueCat is unreachable.
- When Pro ends, extra custom tones, Pro shortcuts and Pro icons lock gracefully (padlock + explanation) instead of disappearing.

## Privacy

- **Screenshots never leave the iPhone.** Text is extracted on device with Apple Vision OCR.
- **Only the conversation text is sent, and only after explicit consent** (onboarding consent screen naming the AI providers; can be withdrawn in Settings › AI sharing).
- The server routes requests through OpenRouter to **zero-data-retention** providers only (Google Gemini, fallback Anthropic Claude). Conversation text is processed in real time and **never stored**.
- No account, no ads, no tracking. The only identifier is the anonymous RevenueCat ID.

## Architecture

```
iPhone (SwiftUI, iOS 18+)
  Back Tap ─▶ Shortcut "TapReply" ─▶ App Intent "Analyze"
      │
      ├─ Vision OCR on device ─▶ ScreenshotParser (who said what, draft in the input field)
      ├─ GenerationClient ─▶ HTTPS ─▶ Supabase Edge Function (Deno / TypeScript)
      │                                  ├─ identity check (RevenueCat anonymous ID, fail closed)
      │                                  ├─ rate limits + global hourly cap (Postgres RPCs)
      │                                  ├─ RevenueCat REST v2: entitlement check, credit debit / refund
      │                                  └─ OpenRouter (ZDR) ─▶ Gemini, fallback Claude
      └─ Reply ─▶ clipboard + Live Activity (widget extension) + local history (SwiftData)
```

Other details judges may enjoy:

- **TapTap**, the mascot, is a real-time vector animation engine: 50+ animation clips stored in a compact custom format (`.ttapz`: int16 deltas, zlib), decoded at runtime, recolored with the user's color, rendered with SwiftUI `Canvas` + `TimelineView`.
- A 7-act animated onboarding that sets up the Shortcut and Back Tap step by step.
- A server-side Fact Check preset with safety rules and a visible disclaimer.

## Repository structure

```
TapReply/                   iOS app (SwiftUI)
  Intents/                  App Intents (Analyze), runner
  OCR/                      Vision OCR + conversation parser
  Services/                 PurchaseService (RevenueCat), GenerationClient, ReplyPipeline, LiveActivity, History
  Views/                    Onboarding, Home, Studio (tones), Test, History, Settings, Paywall
  DesignSystem/TapTap/      vector animation engine for the mascot
  TapTapAssets/             animation clips (.ttapz)
  Localizable.xcstrings     6 languages
TapReplyWidgets/            Live Activity / Dynamic Island widget
backend/supabase/
  functions/tapreply-generate/   main Edge Function (AI + RevenueCat credits)
  functions/tapreply-stats/      private stats endpoint
  schema.sql                     tables, RLS, RPCs
website/                    privacy and support pages (Vercel)
```

## Run it yourself

**Requirements:** Xcode 16 or later, an iPhone on iOS 18+ (Back Tap needs a physical iPhone), a RevenueCat project, a Supabase project, an OpenRouter API key.

1. **App**
   - Open `TapReply.xcodeproj`. Swift Package Manager fetches RevenueCat (`purchases-ios-spm`).
   - Set your own Team and bundle identifiers (app + widget, same App Group).
   - In `TapReply/Config.swift`, set `backendURL`, `supabaseAnonKey` and `revenueCatAPIKey` (public keys only).
   - In RevenueCat, create the entitlement `pro`, the products (monthly, annual with a 3-day trial, consumable 50 pack), a default offering, and a virtual currency with code `RPLY`.
2. **Backend**
   - Run `backend/supabase/schema.sql` in the Supabase SQL editor.
   - Deploy the functions: `supabase functions deploy tapreply-generate --no-verify-jwt` and `supabase functions deploy tapreply-stats --no-verify-jwt`.
   - Set the secrets: `OPENROUTER_API_KEY`, `RC_SECRET_API_KEY` (RevenueCat v2 secret key), `RC_PROJECT_ID`, optional `RC_PRO_ENTITLEMENT_ID`, optional `GLOBAL_GEN_PER_HOUR`. `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided by Supabase.
3. **Shortcut + Back Tap**
   - Run the app: the onboarding installs the shared Shortcut and shows the Back Tap setting path.
   - Or open the **Test** tab and double-tap the back of the iPhone.

No secret is stored in this repository: the keys in `Config.swift` are public client keys by design, and all server secrets are environment variables.

## License

[MIT](LICENSE) © 2026 Pierre Madi
