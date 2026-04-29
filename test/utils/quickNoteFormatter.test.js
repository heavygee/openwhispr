const test = require("node:test");
const assert = require("node:assert/strict");

const {
  DEFAULT_QUICK_NOTE_PROMPT,
  QUICK_NOTES_FOLDER_NAME,
  buildQuickNoteSystemPrompt,
  formatQuickNoteWithReasoning,
  parseQuickNoteResponse,
} = require("../../src/utils/quickNoteFormatter");

const FIXED_DATE = new Date("2026-04-29T10:50:00.000Z");

test("parseQuickNoteResponse accepts strict JSON title and markdown content", () => {
  const parsed = parseQuickNoteResponse(
    JSON.stringify({
      title: "Mind map idea",
      content: "## Idea\n\n- Send this to the AI mindmapping project.",
    }),
    "send this to mindmapping",
    FIXED_DATE
  );

  assert.deepEqual(parsed, {
    title: "Mind map idea",
    content: "## Idea\n\n- Send this to the AI mindmapping project.",
    usedFallback: false,
  });
});

test("parseQuickNoteResponse falls back to raw transcript on invalid model output", () => {
  const parsed = parseQuickNoteResponse("not json", "remember to buy coffee", FIXED_DATE);

  assert.deepEqual(parsed, {
    title: "Quick Note - 2026-04-29",
    content: "remember to buy coffee",
    usedFallback: true,
  });
});

test("formatQuickNoteWithReasoning passes custom prompt and parses fenced JSON", async () => {
  let receivedConfig = null;

  const parsed = await formatQuickNoteWithReasoning("capture this", {
    now: FIXED_DATE,
    quickNotePrompt: "Custom quick prompt",
    reasoningFn: async (_text, config) => {
      receivedConfig = config;
      return '```json\n{"title":"Captured","content":"- capture this"}\n```';
    },
  });

  assert.equal(receivedConfig.systemPrompt.includes("Custom quick prompt"), true);
  assert.equal(receivedConfig.temperature, 0.2);
  assert.deepEqual(parsed, {
    title: "Captured",
    content: "- capture this",
    usedFallback: false,
  });
});

test("formatQuickNoteWithReasoning falls back when reasoning throws", async () => {
  const parsed = await formatQuickNoteWithReasoning("raw thought", {
    now: FIXED_DATE,
    reasoningFn: async () => {
      throw new Error("nope");
    },
  });

  assert.deepEqual(parsed, {
    title: "Quick Note - 2026-04-29",
    content: "raw thought",
    usedFallback: true,
  });
});

test("quick note constants match the v1 contract", () => {
  assert.equal(QUICK_NOTES_FOLDER_NAME, "Quick Notes");
  assert.equal(buildQuickNoteSystemPrompt("").includes(DEFAULT_QUICK_NOTE_PROMPT), true);
});
