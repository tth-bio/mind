GITHUB PAGES — QUICK SETUP

1. Create a new GitHub repository.
2. Upload these items to the repository root:
   - index.html
   - style.css
   - script.js
   - assets/site1-video.mp4

   The folder structure must be:

   /
   ├── index.html
   ├── style.css
   ├── script.js
   └── assets/
       └── site1-video.mp4

3. Open the repository:
   Settings → Pages
4. Under "Build and deployment":
   Source: Deploy from a branch
   Branch: main
   Folder: / (root)
5. Save.
6. GitHub will give you the Pages address.

IMPORTANT:
- Do not rename site1-video.mp4 unless you also change the src in index.html.
- The character is NOT generated or replaced. The supplied video is used directly.
- The cursor interaction scrubs through the supplied video: the character's existing left/right movement becomes the "looking at the cursor" effect.
- The video is about 4 MB, so it is small enough for a normal GitHub Pages static site.

If you use a repository such as username.github.io, the site will be at:
https://username.github.io/
