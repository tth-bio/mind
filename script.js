const video = document.getElementById("character");
const cursor = document.querySelector(".cursor");

let target = 0.5;
let position = 0.5;
let lastSeek = 0;

const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

window.addEventListener("pointermove", (e) => {
  target = clamp(e.clientX / window.innerWidth, 0, 1);
  if (cursor) {
    cursor.style.left = `${e.clientX}px`;
    cursor.style.top = `${e.clientY}px`;
  }
}, { passive: true });

video.addEventListener("loadedmetadata", () => {
  video.pause();
  video.currentTime = video.duration * 0.5;
});

function frame(now) {
  position += (target - position) * 0.14;

  if (video.readyState >= 2 && Number.isFinite(video.duration) && now - lastSeek > 55) {
    video.currentTime = position * Math.max(video.duration - 0.03, 0);
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
