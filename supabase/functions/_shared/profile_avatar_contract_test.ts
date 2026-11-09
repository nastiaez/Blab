const sql = await Deno.readTextFile(
  new URL(
    "../../migrations/20261107000001_profile_photos.sql",
    import.meta.url,
  ),
);
const deletion = await Deno.readTextFile(
  new URL("../delete-account/index.ts", import.meta.url),
);
const worker = await Deno.readTextFile(
  new URL("../reconcile-stream-events/index.ts", import.meta.url),
);
Deno.test("avatar static contract: no public bucket or login-time import", () => {
  if (
    !sql.includes("false,5242880,array['image/jpeg']") ||
    !sql.includes("before insert on public.profiles") ||
    sql.includes("after update on auth.users")
  ) throw Error("private_or_insert_boundary");
});
Deno.test("avatar static contract: actor bound, queue leased, active object excluded", () => {
  for (
    const s of [
      "actor is distinct from p_expected_actor",
      "status='pending' for update",
      "not exists(select 1 from profiles p where p.avatar_path=q.object_path)",
      "for update skip locked",
      "lease_token=p_lease",
    ]
  ) if (!sql.includes(s)) throw Error(s);
});
Deno.test("avatar static contract: deletion queues and verifies bytes before Auth deletion", () => {
  const queue = deletion.indexOf("queue_profile_avatar_account_erasure");
  const remove = deletion.indexOf("avatar_removal_unconfirmed");
  const auth = deletion.indexOf("admin.auth.admin.deleteUser");
  if (queue < 0 || remove < queue || auth < remove) {
    throw Error("avatar_erasure_order");
  }
});
Deno.test("avatar static contract: recovery owns versioned lease and physical verification", () => {
  for (
    const s of [
      "claim_profile_avatar_cleanup",
      "finish_profile_avatar_cleanup",
      "p_lease: row.lease_token",
      "isMissingPrivateObject(probe.error)",
    ]
  ) if (!worker.includes(s)) throw Error(s);
});

Deno.test("avatar cleanup runs before unrelated Stream configuration gate", () => {
  const cleanup = worker.indexOf("claim_profile_avatar_cleanup");
  const gate = worker.indexOf("stream_not_configured");
  if (cleanup < 0 || cleanup > gate) throw Error("avatar_cleanup_blocked_by_stream");
});
