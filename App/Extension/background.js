const api = globalThis.browser ?? globalThis.chrome;
const isSafari = api.runtime.getURL("").startsWith("safari-web-extension://");
const browserName = isSafari ? "safari" : "chrome";
const DEFAULT_PORT = 47635;
const RECONNECT_MIN_MS = 1000;
const RECONNECT_MAX_MS = 30000;

const tabs = new Map();
const gains = new Map();
let socket = null;
let reconnectDelay = RECONNECT_MIN_MS;
let reconnectTimer = null;

const hostOf = url => {
  try { return new URL(url).hostname.replace(/^www\./, ""); } catch { return ""; }
};

const rememberTab = tab => {
  const previous = tabs.get(tab.id) ?? { playingFrames: new Set(), control: new Map(), tracked: new Map() };
  tabs.set(tab.id, {
    id: tab.id,
    title: tab.title ?? previous.title ?? "",
    host: hostOf(tab.url ?? tab.pendingUrl ?? previous.url ?? ""),
    url: tab.url ?? previous.url ?? "",
    favicon: tab.favIconUrl ?? previous.favicon ?? "",
    audible: Boolean(tab.audible),
    playingFrames: previous.playingFrames,
    control: previous.control,
    tracked: previous.tracked
  });
};

const isAdjusted = tab => (gains.get(tab.id) ?? 1) < 1;
const isPlaying = tab => tab.playingFrames.size > 0 || tab.audible || isAdjusted(tab);
const trackedCount = tab => [...tab.tracked.values()].reduce((sum, count) => sum + count, 0);

const snapshot = () => [...tabs.values()]
  .filter(isPlaying)
  .map(tab => ({ id: tab.id, title: tab.title, host: tab.host, favicon: tab.favicon, playing: tab.playingFrames.size > 0 || tab.audible, gain: gains.get(tab.id) ?? 1, control: [...tab.control.values()].some(mode => mode !== "none"), tracked: trackedCount(tab) }));

const send = message => {
  if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify(message));
};

const publishTabs = () => send({ type: "tabs", tabs: snapshot() });

const applyGain = (tabId, gain) => {
  gains.set(tabId, gain);
  api.tabs.sendMessage(tabId, { type: "gain", gain }).catch(() => {});
  publishTabs();
};

const loadConfig = async () => {
  if (isSafari) {
    const response = await api.runtime.sendNativeMessage("application.id", { type: "config" });
    return { port: response?.port ?? DEFAULT_PORT, token: response?.token ?? "" };
  }
  const stored = await api.storage.local.get(["port", "token"]);
  return { port: stored.port ?? DEFAULT_PORT, token: stored.token ?? "" };
};

const scheduleReconnect = () => {
  if (reconnectTimer) return;
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    connect();
  }, reconnectDelay);
  reconnectDelay = Math.min(reconnectDelay * 2, RECONNECT_MAX_MS);
};

const handleMessage = message => {
  switch (message.type) {
    case "welcome":
      reconnectDelay = RECONNECT_MIN_MS;
      publishTabs();
      break;
    case "gain":
      applyGain(message.tabId, Number(message.gain));
      break;
    case "ping":
      send({ type: "pong" });
      break;
  }
};

const connect = async () => {
  if (socket && socket.readyState !== WebSocket.CLOSED) return;
  const config = await loadConfig();
  if (!config.token) { scheduleReconnect(); return; }
  socket = new WebSocket(`ws://127.0.0.1:${config.port}`);
  socket.addEventListener("open", () => send({ type: "hello", token: config.token, browser: browserName, version: api.runtime.getManifest().version }));
  socket.addEventListener("message", event => {
    try { handleMessage(JSON.parse(event.data)); } catch {}
  });
  socket.addEventListener("close", () => { socket = null; scheduleReconnect(); });
  socket.addEventListener("error", () => socket?.close());
};

api.tabs.onUpdated.addListener((tabId, changes, tab) => {
  rememberTab(tab);
  if ("audible" in changes || "title" in changes || "favIconUrl" in changes || "url" in changes) publishTabs();
});

api.tabs.onRemoved.addListener(tabId => {
  tabs.delete(tabId);
  gains.delete(tabId);
  publishTabs();
});

api.runtime.onMessage.addListener((message, sender, sendResponse) => {
  const tabId = sender.tab?.id;
  if (tabId === undefined) return;
  if (!tabs.has(tabId)) rememberTab(sender.tab);
  if (message.type === "hello") {
    sendResponse({ gain: gains.get(tabId) ?? 1 });
    return;
  }
  if (message.type === "state") {
    const tab = tabs.get(tabId);
    if (!tab) return;
    const frameId = sender.frameId ?? 0;
    const wasPlaying = isPlaying(tab);
    const hadControl = [...tab.control.values()].some(mode => mode !== "none");
    if (message.playing) tab.playingFrames.add(frameId); else tab.playingFrames.delete(frameId);
    const hadTracked = trackedCount(tab);
    tab.tracked.set(frameId, message.tracked ?? 0);
    if (message.tracked > 0) tab.control.set(frameId, message.control);
    const hasControl = [...tab.control.values()].some(mode => mode !== "none");
    if (wasPlaying !== isPlaying(tab) || hadControl !== hasControl || hadTracked !== trackedCount(tab)) publishTabs();
  }
});

api.alarms.onAlarm.addListener(alarm => {
  if (alarm.name === "reconnect") connect();
});

api.alarms.create("reconnect", { periodInMinutes: 0.5 });
api.tabs.query({}).then(all => { all.forEach(rememberTab); connect(); });
