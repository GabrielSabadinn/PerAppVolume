(() => {
  const api = globalThis.browser ?? globalThis.chrome;

  const dispatchToPage = (type, detail) => window.dispatchEvent(new CustomEvent(type, { detail }));

  let control = "none";

  window.addEventListener("perappvolume:state", event => {
    api.runtime.sendMessage({ type: "state", playing: Boolean(event.detail?.playing), control, tracked: event.detail?.tracked ?? 0 }).catch(() => {});
  });

  api.runtime.onMessage.addListener(message => {
    if (message?.type === "gain") dispatchToPage("perappvolume:set-gain", { gain: message.gain });
  });

  const injectFallback = () => {
    const script = document.createElement("script");
    script.src = api.runtime.getURL("injected.js");
    script.addEventListener("load", () => script.remove());
    (document.head || document.documentElement).appendChild(script);
  };

  const ensureInjected = () => {
    let answered = false;
    const onPong = () => { answered = true; };
    window.addEventListener("perappvolume:pong", onPong, { once: true });
    dispatchToPage("perappvolume:ping");
    window.removeEventListener("perappvolume:pong", onPong);
    if (answered) { control = "main"; return; }
    injectFallback();
    setTimeout(() => {
      window.addEventListener("perappvolume:pong", () => { control = "fallback"; }, { once: true });
      dispatchToPage("perappvolume:ping");
    }, 300);
  };

  const requestGain = () => {
    api.runtime.sendMessage({ type: "hello" })
      .then(response => { if (response?.gain !== undefined) dispatchToPage("perappvolume:set-gain", { gain: response.gain }); })
      .catch(() => {});
  };

  setTimeout(() => {
    ensureInjected();
    requestGain();
  }, 0);
})();
