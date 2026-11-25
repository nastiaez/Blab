const reasons: Record<string, string> = {
  incorrect: "Incorrect translation",
  partial: "Incomplete translation",
  wrong_language: "Wrong language",
  failing: "Translation failed",
  other: "Other translation problem",
};

export type Report = { report_id: string; reason: string };

type Issue = { id: string; identifier: string; team: { id: string } };

export async function deliverReport(
  report: Report,
  apiKey: string,
  teamId: string,
  request = fetch,
): Promise<string> {
  async function query<T>(
    document: string,
    variables: Record<string, unknown>,
  ): Promise<T> {
    const response = await request("https://api.linear.app/graphql", {
      method: "POST",
      headers: { Authorization: apiKey, "Content-Type": "application/json" },
      body: JSON.stringify({ query: document, variables }),
      signal: AbortSignal.timeout(8000),
    });
    if (!response.ok) throw new Error("linear_request_failed");
    const result = await response.json();
    if (result.errors?.length || !result.data) {
      throw new Error("linear_request_failed");
    }
    return result.data;
  }

  const fields = "id identifier team { id }";
  const reason = reasons[report.reason];
  if (!reason) throw new Error("unknown_report_reason");

  // Use the report UUID so retries after an ambiguous response cannot create
  // another issue. Resolve that same UUID if the mutation already succeeded.
  let issue: Issue | undefined;
  try {
    const result = await query<{
      issueCreate: { success: boolean; issue?: Issue };
    }>(
      `mutation CreateReport($input: IssueCreateInput!) {
      issueCreate(input: $input) { success issue { ${fields} } }
    }`,
      {
        input: {
          id: report.report_id,
          teamId,
          title: `Translation report: ${reason}`,
          description: `Blab report reference: \`${report.report_id}\``,
          useDefaultTemplate: false,
        },
      },
    );
    if (result.issueCreate.success) issue = result.issueCreate.issue;
  } catch {
    // Linear error bodies are not persisted or logged.
  }
  if (!issue) {
    const result = await query<{ issue: Issue }>(
      `query FindReport($id: String!) { issue(id: $id) { ${fields} } }`,
      { id: report.report_id },
    );
    issue = result.issue;
  }
  if (
    issue?.id !== report.report_id || issue.team?.id !== teamId ||
    !/^[A-Z][A-Z0-9]*-[0-9]+$/.test(issue.identifier)
  ) {
    throw new Error("linear_issue_unconfirmed");
  }
  return issue.identifier;
}
