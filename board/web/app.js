const boardElement = document.getElementById("board");
const updatedAtElement = document.getElementById("updated-at");
const cardCountElement = document.getElementById("card-count");
const saveStatusElement = document.getElementById("save-status");
const reloadButton = document.getElementById("reload-button");
const saveButton = document.getElementById("save-button");
const inspectorEmpty = document.getElementById("inspector-empty");
const inspectorForm = document.getElementById("inspector-form");
const inspectorHeading = document.getElementById("inspector-heading");
const inspectorCardId = document.getElementById("inspector-card-id");
const fieldTitle = document.getElementById("field-title");
const fieldTags = document.getElementById("field-tags");
const fieldLinks = document.getElementById("field-links");
const fieldDescription = document.getElementById("field-description");
const duplicateCardButton = document.getElementById("duplicate-card");
const deleteCardButton = document.getElementById("delete-card");
const copyCardIdButton = document.getElementById("copy-card-id");

let boardState = null;
let selectedCardId = null;
let saveTimer = null;
let isSaving = false;
let queuedSave = false;
let draggingCardId = null;

reloadButton.addEventListener("click", () => {
  loadBoard();
});

saveButton.addEventListener("click", () => {
  saveBoardNow();
});

fieldTitle.addEventListener("input", () => updateSelectedCard("title", fieldTitle.value));
fieldTags.addEventListener("input", () => updateSelectedCard("tags", parseList(fieldTags.value)));
fieldLinks.addEventListener("input", () => updateSelectedCard("links", parseList(fieldLinks.value)));
fieldDescription.addEventListener("input", () => updateSelectedCard("description", fieldDescription.value));

duplicateCardButton.addEventListener("click", () => {
  if (!selectedCardId) {
    return;
  }
  const match = findCard(selectedCardId);
  if (!match) {
    return;
  }
  const copy = structuredClone(match.card);
  copy.id = newCardId();
  copy.key = "";
  copy.title = `${copy.title} copy`;
  match.column.cards.splice(match.index + 1, 0, copy);
  selectedCardId = copy.id;
  renderBoard();
  scheduleSave();
});

deleteCardButton.addEventListener("click", () => {
  if (!selectedCardId) {
    return;
  }
  const match = findCard(selectedCardId);
  if (!match) {
    return;
  }
  match.column.cards.splice(match.index, 1);
  selectedCardId = null;
  renderBoard();
  scheduleSave();
});

copyCardIdButton.addEventListener("click", async () => {
  const match = findCard(selectedCardId);
  if (!match) {
    return;
  }
  try {
    await navigator.clipboard.writeText(String(match.card.id));
    setStatus(`Copied ${match.card.id}`);
  } catch (error) {
    console.error(error);
    setStatus("Copy failed", true);
  }
});

loadBoard();

async function loadBoard() {
  setStatus("Loading...");
  try {
    const response = await fetch("/api/board", { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`load failed: ${response.status}`);
    }
    boardState = await response.json();
    if (!findCard(selectedCardId)) {
      selectedCardId = null;
    }
    renderBoard();
    setStatus("Loaded");
  } catch (error) {
    console.error(error);
    setStatus("Load failed", true);
  }
}

function renderBoard() {
  if (!boardState) {
    return;
  }

  boardElement.innerHTML = "";
  let totalCards = 0;

  for (const column of boardState.columns) {
    totalCards += column.cards.length;
    boardElement.appendChild(renderColumn(column));
  }

  updatedAtElement.textContent = formatTimestamp(boardState.updated_at);
  cardCountElement.textContent = String(totalCards);
  renderInspector();
}

function renderColumn(column) {
  const section = document.createElement("section");
  section.className = "column";
  section.dataset.columnId = column.id;

  const header = document.createElement("header");
  header.className = "column-header";

  const title = document.createElement("h2");
  title.textContent = column.title;
  header.appendChild(title);

  const meta = document.createElement("div");
  meta.className = "column-meta";

  const count = document.createElement("span");
  count.className = "column-count";
  count.textContent = `${column.cards.length} cards`;
  meta.appendChild(count);

  const addButton = document.createElement("button");
  addButton.className = "add-card-button";
  addButton.type = "button";
  addButton.textContent = "+";
  addButton.title = "Add card";
  addButton.addEventListener("click", () => addCard(column.id));
  meta.appendChild(addButton);

  header.appendChild(meta);
  section.appendChild(header);

  const dropzone = document.createElement("div");
  dropzone.className = "column-dropzone";
  dropzone.dataset.columnId = column.id;
  dropzone.addEventListener("dragover", (event) => handleDragOver(event, column.id));
  dropzone.addEventListener("dragleave", () => dropzone.classList.remove("is-over"));
  dropzone.addEventListener("drop", (event) => handleDrop(event, column.id));

  for (const card of column.cards) {
    dropzone.appendChild(renderCard(card));
  }

  section.appendChild(dropzone);
  return section;
}

function renderCard(card) {
  const article = document.createElement("article");
  article.className = "card";
  if (sameCardId(card.id, selectedCardId)) {
    article.classList.add("is-selected");
  }
  article.draggable = true;
  article.dataset.cardId = card.id;

  article.addEventListener("click", () => {
    selectedCardId = card.id;
    renderBoard();
  });

  article.addEventListener("dragstart", () => {
    draggingCardId = card.id;
    article.classList.add("is-dragging");
  });

  article.addEventListener("dragend", () => {
    draggingCardId = null;
    article.classList.remove("is-dragging");
    document.querySelectorAll(".column-dropzone.is-over").forEach((node) => {
      node.classList.remove("is-over");
    });
  });

  const cardHeader = document.createElement("div");
  cardHeader.className = "card-header";

  const cardId = document.createElement("span");
  cardId.className = "card-id";
  cardId.textContent = String(card.id);
  cardHeader.appendChild(cardId);

  const heading = document.createElement("h3");
  heading.textContent = card.title;
  cardHeader.appendChild(heading);
  article.appendChild(cardHeader);

  if (card.description) {
    const body = document.createElement("p");
    body.textContent = previewText(card.description);
    article.appendChild(body);
  }

  if (Array.isArray(card.tags) && card.tags.length > 0) {
    const tags = document.createElement("div");
    tags.className = "card-tags";
    for (const tag of card.tags) {
      const chip = document.createElement("span");
      chip.className = "tag";
      chip.textContent = tag;
      tags.appendChild(chip);
    }
    article.appendChild(tags);
  }

  if (Array.isArray(card.links) && card.links.length > 0) {
    const links = document.createElement("div");
    links.className = "card-links";
    for (const link of card.links) {
      const chip = document.createElement("span");
      chip.className = "link-chip";
      chip.textContent = link;
      links.appendChild(chip);
    }
    article.appendChild(links);
  }

  return article;
}

function renderInspector() {
  const match = findCard(selectedCardId);
  if (!match) {
    inspectorEmpty.hidden = false;
    inspectorForm.hidden = true;
    return;
  }

  inspectorEmpty.hidden = true;
  inspectorForm.hidden = false;
  inspectorHeading.textContent = match.card.title || "Card Inspector";
  inspectorCardId.textContent = String(match.card.id);
  fieldTitle.value = match.card.title || "";
  fieldTags.value = joinList(match.card.tags);
  fieldLinks.value = joinList(match.card.links);
  fieldDescription.value = match.card.description || "";
}

function addCard(columnId) {
  const column = boardState.columns.find((candidate) => candidate.id === columnId);
  if (!column) {
    return;
  }
  const nextId = newCardId();
  const card = {
    id: nextId,
    key: "",
    title: "New card",
    description: "",
    tags: [],
    links: []
  };
  column.cards.unshift(card);
  selectedCardId = card.id;
  renderBoard();
  scheduleSave();
}

function updateSelectedCard(field, value) {
  const match = findCard(selectedCardId);
  if (!match) {
    return;
  }
  match.card[field] = value;
  if (field === "title") {
    inspectorHeading.textContent = value || "Card Inspector";
    const cardHeading = document.querySelector(`.card[data-card-id="${selectedCardId}"] h3`);
    if (cardHeading) {
      cardHeading.textContent = value || "Untitled";
    }
  }
  scheduleSave();
}

function handleDragOver(event, columnId) {
  if (!draggingCardId) {
    return;
  }
  event.preventDefault();
  const dropzone = boardElement.querySelector(`.column-dropzone[data-column-id="${columnId}"]`);
  if (!dropzone) {
    return;
  }
  dropzone.classList.add("is-over");
}

function handleDrop(event, columnId) {
  event.preventDefault();
  const dropzone = boardElement.querySelector(`.column-dropzone[data-column-id="${columnId}"]`);
  if (!dropzone) {
    return;
  }
  dropzone.classList.remove("is-over");
  if (!draggingCardId) {
    return;
  }

  moveCard(draggingCardId, columnId, computeDropIndex(dropzone, event));
}

function moveCard(cardId, targetColumnId, targetIndex) {
  const source = findCard(cardId);
  const targetColumn = boardState.columns.find((column) => column.id === targetColumnId);
  if (!source || !targetColumn) {
    return;
  }

  source.column.cards.splice(source.index, 1);

  let nextIndex = targetIndex;
  if (source.column.id === targetColumnId && source.index < targetIndex) {
    nextIndex -= 1;
  }
  nextIndex = Math.max(0, Math.min(targetColumn.cards.length, nextIndex));

  targetColumn.cards.splice(nextIndex, 0, source.card);
  selectedCardId = source.card.id;
  renderBoard();
  scheduleSave();
}

function computeDropIndex(dropzone, event) {
  const cardElements = [...dropzone.querySelectorAll(".card:not(.is-dragging)")];
  let nextIndex = cardElements.length;

  for (let index = 0; index < cardElements.length; index += 1) {
    const rect = cardElements[index].getBoundingClientRect();
    if (event.clientY < rect.top + rect.height / 2) {
      nextIndex = index;
      break;
    }
  }

  return nextIndex;
}

function findCard(cardId) {
  if (!boardState || !cardId) {
    return null;
  }
  for (const column of boardState.columns) {
    const index = column.cards.findIndex((card) => sameCardId(card.id, cardId));
    if (index !== -1) {
      return { card: column.cards[index], column, index };
    }
  }
  return null;
}

function scheduleSave() {
  setStatus("Saving...");
  clearTimeout(saveTimer);
  saveTimer = window.setTimeout(() => {
    saveBoardNow();
  }, 500);
}

async function saveBoardNow() {
  if (!boardState) {
    return;
  }
  if (isSaving) {
    queuedSave = true;
    return;
  }
  isSaving = true;
  setStatus("Saving...");
  try {
    const response = await fetch("/api/board", {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(boardState)
    });
    if (!response.ok) {
      throw new Error(`save failed: ${response.status}`);
    }
    boardState = await response.json();
    renderBoard();
    setStatus("Saved");
  } catch (error) {
    console.error(error);
    setStatus("Save failed", true);
  } finally {
    isSaving = false;
    if (queuedSave) {
      queuedSave = false;
      saveBoardNow();
    }
  }
}

function setStatus(message, isError = false) {
  saveStatusElement.textContent = message;
  saveStatusElement.classList.toggle("is-error", isError);
}

function newCardId() {
  let maxId = 0;
  for (const column of boardState.columns) {
    for (const card of column.cards) {
      if (typeof card.id === "number" && Number.isInteger(card.id)) {
        maxId = Math.max(maxId, card.id);
      }
    }
  }
  return maxId + 1;
}

function sameCardId(left, right) {
  return String(left) === String(right);
}

function parseList(value) {
  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function joinList(items) {
  return Array.isArray(items) ? items.join(", ") : "";
}

function previewText(value) {
  return value.length > 120 ? `${value.slice(0, 117)}...` : value;
}

function formatTimestamp(value) {
  if (!value) {
    return "-";
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return value;
  }
  return new Intl.DateTimeFormat("ja-JP", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit"
  }).format(parsed);
}
