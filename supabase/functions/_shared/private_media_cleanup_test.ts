import { isMissingPrivateObject } from "./private_media_cleanup.ts";
Deno.test("only a confirmed missing object can settle physical photo cleanup", () => {
  if (
    !isMissingPrivateObject({
      statusCode: "404",
      message: "Object not found",
    }) ||
    !isMissingPrivateObject({
      statusCode: "400",
      message: "Object does not exist",
    })
  ) throw new Error("missing_not_accepted");
  for (
    const error of [null, { statusCode: "401", message: "Object not found" }, {
      statusCode: "500",
      message: "Object not found",
    }, { statusCode: "400", message: "Bucket not found" }]
  ) {
    if (isMissingPrivateObject(error)) throw new Error("false_cleanup_success");
  }
});
