const video = document.getElementById("character");
const cursor = document.querySelector(".cursor");

let target = 0.5;
let position = 0.5;
let lastPointer = 0.5;
let lastSeek = 0;
let idleTimer;

const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

function setPointer(x) {
  const ratio = clamp(x / window.innerWidth, 0, 1);
  lastPointer = ratio;
  target = ratio;

  if (cursor) {
    cursor.style.left = `${x}px`;
  }
}

window.addEventListener("pointermove", (e) => {
  setPointer(e.clientX);
  if (cursor) cursor.style.top = `${e.clientY}px`;
  clearTimeout(idleTimer);
  idleTimer = setTimeout(() => { target = lastPointer; }, 700);
}, { passive: true });

video.addEventListener("loadedmetadata", () => {
  video.pause();
  video.currentTime = video.duration * 0.5;
  position = target = 0.5;
});

function frame(now) {
  // Smooth target interpolation, but seek only ~18 times/sec.
  // This avoids forcing the browser to decode a new frame on every RAF.
  position += (target - position) * 0.14;

  if (video.readyState >= 2 && Number.isFinite(video.duration) && now - lastSeek > 55) {
    const t = position * Math.max(video.duration - 0.03, 0);
    video.currentTime = t;
    lastSeek = now;
  }

  requestAnimationFrame(frame);
}

document.querySelectorAll("a").forEach((a) => {
  a.addEventListener("mouseenter", () => {
    if (cursor) { cursor.style.width = "16px"; cursor.style.height = "16px"; }
  });
  a.addEventListener("mouseleave", () => {
    if (cursor) { cursor.style.width = "8px"; cursor.style.height = "8px"; }
  });
});

requestAnimationFrame(frame);
