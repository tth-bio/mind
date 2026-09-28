const video = document.getElementById("character");
const cursor = document.querySelector(".cursor");

let targetTime = 2.5;
let currentTime = 2.5;
let lastMove = performance.now();
let pointerX = window.innerWidth / 2;

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

// The supplied 5-second video already contains the character turning.
// We scrub through that exact footage according to the cursor position,
// so the character visually follows the user's pointer without generating
// or replacing the character.
function updateTargetFromPointer(x) {
  pointerX = x;
  const ratio = clamp(x / window.innerWidth, 0, 1);
  targetTime = ratio * Math.max(video.duration - 0.05, 0);
  lastMove = performance.now();
}

window.addEventListener("pointermove", (event) => {
  updateTargetFromPointer(event.clientX);

  if (cursor) {
    cursor.style.left = `${event.clientX}px`;
    cursor.style.top = `${event.clientY}px`;
  }
}, { passive: true });

document.querySelectorAll("a").forEach((link) => {
  link.addEventListener("mouseenter", () => {
    if (cursor) {
      cursor.style.width = "18px";
      cursor.style.height = "18px";
    }
  });

  link.addEventListener("mouseleave", () => {
    if (cursor) {
      cursor.style.width = "9px";
      cursor.style.height = "9px";
    }
  });
});

video.addEventListener("loadedmetadata", () => {
  currentTime = video.duration * 0.5;
  targetTime = currentTime;
  video.currentTime = currentTime;
});

function animate() {
  const now = performance.now();

  // Smoothly move through the supplied footage.
  currentTime += (targetTime - currentTime) * 0.085;

  if (video.readyState >= 2 && Number.isFinite(video.duration)) {
    video.currentTime = clamp(currentTime, 0, Math.max(video.duration - 0.04, 0));
  }

  // When the pointer is still, keep a tiny breathing motion instead of
  // starting a normal loop that would break the cursor-to-head relationship.
  if (now - lastMove > 1800 && video.duration) {
    const idle = (Math.sin(now * 0.00065) + 1) / 2;
    targetTime = video.duration * (0.44 + idle * 0.12);
  }

  requestAnimationFrame(animate);
}

animate();

window.addEventListener("resize", () => {
  updateTargetFromPointer(pointerX);
});
