import { assert, assertEquals } from "jsr:@std/assert";

Deno.test("send-push resolves source media before constructing recipient previews", async (t) => {
  const savedFetch = globalThis.fetch;
  const savedServe = Deno.serve;
  const environment = {
    SUPABASE_URL: "https://notification-fixture.invalid",
    SUPABASE_SERVICE_ROLE_KEY: "local-fixture-only",
    PUSH_WEBHOOK_SECRET: "fixture-webhook-with-at-least-24-characters",
    FIREBASE_PROJECT_ID: "fixture-project",
    FIREBASE_CLIENT_EMAIL: "fixture@fixture-project.iam.gserviceaccount.com",
    FIREBASE_PRIVATE_KEY: "",
  };
  const previous = Object.fromEntries(
    Object.keys(environment).map((k) => [k, Deno.env.get(k)]),
  );
  const keys = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const der = new Uint8Array(
    await crypto.subtle.exportKey("pkcs8", keys.privateKey),
  );
  environment.FIREBASE_PRIVATE_KEY = `-----BEGIN PRIVATE KEY-----\n${
    btoa(String.fromCharCode(...der))
  }\n-----END PRIVATE KEY-----`;
  for (const [k, v] of Object.entries(environment)) Deno.env.set(k, v);
  let handler: (r: Request) => Promise<Response>;
  Deno.serve = ((fn: typeof handler) => {
    handler = fn;
    return {};
  }) as unknown as typeof Deno.serve;
  const eventId = "11111111-1111-4111-8111-111111111111";
  const chatId = "22222222-2222-4222-8222-222222222222";
  const messageId = "33333333-3333-4333-8333-333333333333";
  let language = "uk", media = "image", body = "", previews = true;
  let eventType = "chat_message", missingMessage = false;
  let sent: any[] = [], lookups: URL[] = [];
  const response = (value: unknown) => Response.json(value);
  globalThis.fetch = (async (input, init) => {
    const url = new URL(input instanceof Request ? input.url : String(input));
    if (url.hostname === "oauth2.googleapis.com") {
      return response({ access_token: "fixture-access", expires_in: 3600 });
    }
    if (url.hostname === "fcm.googleapis.com") {
      sent.push(JSON.parse(String(init?.body)));
      return response({ name: "fixture-fcm-receipt" });
    }
    assertEquals(
      url.hostname,
      "notification-fixture.invalid",
      "No real service may be called",
    );
    const path = url.pathname;
    if (path.endsWith("/rpc/claim_push_notification_event")) {
      return response([{
        event_id: eventId,
        event_type: eventType,
        recipient_id: "44444444-4444-4444-8444-444444444444",
        actor_name: "Alice",
        interface_language: language,
        chat_id: chatId,
        original_body: body,
      }]);
    }
    if (path.endsWith("/push_notification_events")) {
      assertEquals(url.searchParams.get("id"), `eq.${eventId}`);
      return response({ source_key: messageId });
    }
    if (path.endsWith("/messages")) {
      lookups.push(url);
      assertEquals(url.searchParams.get("id"), `eq.${messageId}`);
      assertEquals(url.searchParams.get("chat_id"), `eq.${chatId}`);
      return response(missingMessage ? null : { message_type: media });
    }
    if (path.endsWith("/push_device_tokens")) {
      return response([{
        token: "fixture-device",
        previews_enabled: previews,
      }]);
    }
    if (path.endsWith("/rpc/reserve_push_notification_delivery")) {
      return response(true);
    }
    if (
      path.endsWith("/rpc/finish_push_notification_delivery") ||
      path.endsWith("/rpc/complete_push_notification_event")
    ) return response(null);
    throw new Error(`Unexpected fixture route ${path}`);
  }) as typeof fetch;
  try {
    await import("./index.ts");
    const invoke = async () => {
      sent = [];
      lookups = [];
      return await handler!(
        new Request("https://handler.invalid", {
          method: "POST",
          headers: {
            "x-blab-push-secret": "fixture-webhook-with-at-least-24-characters",
            "content-type": "application/json",
          },
          body: JSON.stringify({ eventId }),
        }),
      );
    };
    for (
      const [locale, label] of Object.entries({
        en: "Photo",
        uk: "Фото",
        de: "Foto",
        es: "Foto",
      })
    ) {
      await t.step(
        `${locale} photo source lookup and localized delivery`,
        async () => {
          language = locale;
          const r = await invoke();
          assertEquals(r.status, 200);
          assertEquals(await r.json(), {
            status: "processed",
            attempted: 1,
            failures: 0,
          });
          assertEquals(lookups.length, 1);
          assertEquals(sent.length, 1);
          assertEquals(sent[0].message.notification, {
            title: "Alice",
            body: label,
          });
          assertEquals(sent[0].message.data.messageId, messageId);
        },
      );
    }
    await t.step(
      "private photo previews do not expose media type",
      async () => {
        language = "uk";
        previews = false;
        assertEquals((await invoke()).status, 200);
        assertEquals(sent[0].message.notification, {
          title: "Blab",
          body: "У вас нове повідомлення",
        });
      },
    );
    await t.step("text remains authored text, not a photo", async () => {
      previews = true;
      media = "text";
      body = "Hello Bob";
      assertEquals((await invoke()).status, 200);
      assertEquals(sent[0].message.notification.body, body);
    });
    await t.step(
      "missing or wrong-chat source never sends a photo notification",
      async () => {
        missingMessage = true;
        const r = await invoke();
        assertEquals(r.status, 500);
        assertEquals(await r.json(), { error: "message_lookup_failed" });
        assertEquals(sent.length, 0);
      },
    );
    await t.step("invite events do not perform a message lookup", async () => {
      missingMessage = false;
      eventType = "invite_claimed";
      assertEquals((await invoke()).status, 200);
      assertEquals(lookups.length, 0);
      assertEquals(sent.length, 1);
      assert(sent[0].message.notification.body.includes("приєднався"));
    });
  } finally {
    globalThis.fetch = savedFetch;
    Deno.serve = savedServe;
    for (const [k, v] of Object.entries(previous)) {
      if (v === undefined) Deno.env.delete(k);
      else Deno.env.set(k, v);
    }
  }
});
