(() => {
  if (globalThis.chrome?.runtime?.id || globalThis.browser?.runtime?.id) return;
  if (window.__perAppVolumeInjected) return;
  window.__perAppVolumeInjected = true;

  const prototype = HTMLMediaElement.prototype;
  const volumeDescriptor = Object.getOwnPropertyDescriptor(prototype, "volume");
  const srcObjectDescriptor = Object.getOwnPropertyDescriptor(prototype, "srcObject");
  const originalPlay = prototype.play;
  const siteVolumes = new WeakMap();
  const tracked = new Set();
  let gain = 1;

  const siteVolume = element => siteVolumes.has(element) ? siteVolumes.get(element) : volumeDescriptor.get.call(element);

  const applyGain = element => {
    volumeDescriptor.set.call(element, Math.min(1, siteVolume(element) * gain));
  };

  const isAudible = element => !element.paused && !element.ended && !element.muted && siteVolume(element) > 0;

  let pendingReport = null;
  const reportState = () => {
    if (pendingReport) return;
    pendingReport = setTimeout(() => {
      pendingReport = null;
      const playing = [...tracked].some(isAudible);
      window.dispatchEvent(new CustomEvent("perappvolume:state", { detail: { playing, tracked: tracked.size } }));
    }, 80);
  };

  const track = element => {
    if (!(element instanceof HTMLMediaElement) || tracked.has(element)) return;
    tracked.add(element);
    for (const type of ["play", "playing", "pause", "ended", "emptied", "volumechange"]) {
      element.addEventListener(type, reportState);
    }
    applyGain(element);
    reportState();
  };

  Object.defineProperty(prototype, "volume", {
    configurable: true,
    enumerable: volumeDescriptor.enumerable,
    get() { return siteVolume(this); },
    set(value) {
      siteVolumes.set(this, value);
      track(this);
      applyGain(this);
    }
  });

  Object.defineProperty(prototype, "srcObject", {
    configurable: true,
    enumerable: srcObjectDescriptor.enumerable,
    get() { return srcObjectDescriptor.get.call(this); },
    set(value) {
      srcObjectDescriptor.set.call(this, value);
      track(this);
    }
  });

  prototype.play = function () {
    track(this);
    return originalPlay.apply(this, arguments);
  };

  document.addEventListener("play", event => track(event.composedPath()[0]), true);

  window.addEventListener("perappvolume:set-gain", event => {
    gain = Math.max(0, Math.min(1, Number(event.detail?.gain ?? 1)));
    for (const element of tracked) applyGain(element);
    reportState();
  });

  window.addEventListener("perappvolume:ping", () => {
    window.dispatchEvent(new CustomEvent("perappvolume:pong"));
    reportState();
  });
})();
