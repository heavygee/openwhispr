const QUICK_NOTES_FOLDER_NAME = "Quick Notes";

const DEFAULT_QUICK_NOTE_PROMPT = `You format spoken quick-capture notes.

Return only strict JSON with this shape:
{
  "title": "short, specific note title",
  "content": "markdown note body"
}

Rules:
- Preserve the user's intent and concrete details.
- Clean transcription artifacts and obvious filler.
- You may infer useful headings, tasks, tags, and implied context when it helps.
- Do not invent facts that are not grounded in the transcript.
- Keep the title under 80 characters.
- Make content valid Markdown.`;

function fallbackQuickNoteTitle(now = new Date()) {
  const date = now.toISOString().slice(0, 10);
  return `Quick Note - ${date}`;
}

function extractJsonObject(text) {
  if (!text || typeof text !== "string") return null;

  const trimmed = text.trim();
  if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
    return trimmed;
  }

  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced?.[1]) {
    const fencedText = fenced[1].trim();
    if (fencedText.startsWith("{") && fencedText.endsWith("}")) {
      return fencedText;
    }
  }

  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start !== -1 && end > start) {
    return trimmed.slice(start, end + 1);
  }

  return null;
}

function parseQuickNoteResponse(responseText, rawTranscript, now = new Date()) {
  const jsonText = extractJsonObject(responseText);
  if (!jsonText) {
    return buildQuickNoteFallback(rawTranscript, now);
  }

  try {
    const parsed = JSON.parse(jsonText);
    const title = typeof parsed.title === "string" ? parsed.title.trim() : "";
    const content = typeof parsed.content === "string" ? parsed.content.trim() : "";

    if (!title || !content) {
      return buildQuickNoteFallback(rawTranscript, now);
    }

    return {
      title: title.slice(0, 160),
      content,
      usedFallback: false,
    };
  } catch {
    return buildQuickNoteFallback(rawTranscript, now);
  }
}

function buildQuickNoteFallback(rawTranscript, now = new Date()) {
  return {
    title: fallbackQuickNoteTitle(now),
    content: (rawTranscript || "").trim(),
    usedFallback: true,
  };
}

function buildQuickNoteSystemPrompt(customPrompt) {
  const prompt =
    typeof customPrompt === "string" && customPrompt.trim()
      ? customPrompt.trim()
      : DEFAULT_QUICK_NOTE_PROMPT;
  return `${prompt}

The user transcript will be supplied as the user message. Return only the requested JSON.`;
}

async function formatQuickNoteWithReasoning(rawTranscript, options) {
  const transcript = (rawTranscript || "").trim();
  const now = options?.now || new Date();

  if (!transcript) {
    return buildQuickNoteFallback(transcript, now);
  }

  try {
    const responseText = await options.reasoningFn(transcript, {
      systemPrompt: buildQuickNoteSystemPrompt(options.quickNotePrompt),
      maxTokens: options.maxTokens || 1200,
      temperature: options.temperature ?? 0.2,
    });
    return parseQuickNoteResponse(responseText, transcript, now);
  } catch {
    return buildQuickNoteFallback(transcript, now);
  }
}

module.exports = {
  QUICK_NOTES_FOLDER_NAME,
  DEFAULT_QUICK_NOTE_PROMPT,
  buildQuickNoteFallback,
  buildQuickNoteSystemPrompt,
  fallbackQuickNoteTitle,
  formatQuickNoteWithReasoning,
  parseQuickNoteResponse,
};
