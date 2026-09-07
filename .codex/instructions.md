# Blab progress tracker rule

`progress.html` is the owner-facing Play Store launch tracker.

When work matches a task in that file:

1. Keep the task unchecked while it is being designed, implemented, reviewed, or covered only by automated checks.
2. Hand the exact journey to the owner for manual testing on the required device/account setup.
3. Mark the task complete in `progress.html` only after the owner explicitly confirms the manual test passed.
4. Record durable completion by changing that task's `done` value to `true`; do not rely on browser-local checkbox state.
5. If the owner reports a failure, leave the task unchecked, fix the issue, and return the same journey for another manual pass.
6. When a new launch blocker, missing flow, UX gap, or release requirement is discovered, add it to the High priority section in the same turn. Put non-launch work in Later.
7. Keep the dashboard, `tasks/progress.md`, and `tasks/launch/backlog.md` consistent. Never mark one complete while another still says the owner test is pending.

The completion gate is always owner confirmation after manual testing. Passing automated checks alone is not completion.
